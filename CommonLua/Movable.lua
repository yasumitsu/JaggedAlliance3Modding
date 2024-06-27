--- Defines a Destlock object, which is a type of CObject.
---
--- Destlocks are used for path planning and collision avoidance. They represent a circular area that an entity can be "locked" to, preventing it from moving outside of that area.
---
--- The Destlock object has the following properties:
--- - `flags`: A table of flags that define the behavior of the Destlock, such as whether it is visible or if it is on the surface.
--- - `radius`: The radius of the Destlock, in game units.
--- - `GetRadius()`: Returns the radius of the Destlock.
--- - `GetDestlockOwner()`: Returns the entity that owns the Destlock.
DefineClass.Destlock = {
	__parents = { "CObject" },
	--entity = "WayPoint",
	flags = { gofOnSurface = true, efDestlock = true, efVisible = false, cofComponentDestlock = true },
	radius = 6 * guic,
	GetRadius = pf.GetDestlockRadius,
	GetDestlockOwner = pf.GetDestlockOwner,
}

if Libs.Network == "sync" then
	Destlock.flags.gofSyncObject = true
end

----

--- Defines a Movable object, which is a type of Object.
---
--- Movable objects are used for path planning and collision avoidance. They represent entities that can move around the game world.
---
--- The Movable object has the following properties:
--- - `flags`: A table of flags that define the behavior of the Movable, such as whether it is an obstacle or if it is resting.
--- - `pfclass`: The pathfinding class of the Movable.
--- - `pfflags`: The pathfinding flags of the Movable.
--- - `collision_radius`: The collision radius of the Movable.
--- - `collision_radius_mod`: A modifier used to auto-calculate the collision radius based on the radius.
--- - `radius`: The radius of the Movable, in game units.
--- - `forced_collision_radius`: Whether the collision radius is forced.
--- - `forced_destlock_radius`: Whether the destlock radius is forced.
--- - `outside_pathfinder`: Whether the Movable is outside the pathfinder.
--- - `outside_pathfinder_reasons`: The reasons why the Movable is outside the pathfinder.
--- - `last_move_time`: The last time the Movable moved.
--- - `last_move_counter`: A counter for the last move.
---
--- The Movable object also has a number of methods for managing its movement and pathfinding, such as `GetPathFlags`, `ChangePathFlags`, `GetStepLen`, `SetStepLen`, `SetSpeed`, `GetSpeed`, `SetMoveSpeed`, `GetMoveSpeed`, `GetMoveAnim`, `SetMoveAnim`, `GetWaitAnim`, `SetWaitAnim`, `ClearMoveAnim`, `GetMoveTurnAnim`, `SetMoveTurnAnim`, `GetRotationTime`, `SetRotationTime`, `GetRotationSpeed`, `SetRotationSpeed`, `PathEndsBlocked`, `SetDestlockRadius`, `GetDestlockRadius`, `GetDestlock`, `RemoveDestlock`, `GetDestination`, `SetCollisionRadius`, `GetCollisionRadius`, `RestrictArea`, `GetRestrictArea`, `CheckPassable`, `GetPath`, `GetPathLen`, `GetPathPointCount`, `GetPathPoint`, `SetPathPoint`, `IsPathPartial`, `GetPathHash`, `PopPathPoint`, `SetPfClass`, `GetPfClass`, `Step`, `ResolveGotoTarget`, and `ResolveGotoTargetXYZ`.
DefineClass.Movable =
{
	__parents = { "Object" },
	
	flags = {
		cofComponentPath = true, cofComponentAnim = true, cofComponentInterpolation = true, cofComponentCurvature = true, cofComponentCollider = false,
		efPathExecObstacle = true, efResting = true,
	},
	pfclass = 0,
	pfflags = const.pfmDestlockSmart + const.pfmCollisionAvoidance + const.pfmImpassableSource + const.pfmOrient,

	GetPathFlags = pf.GetPathFlags,
	ChangePathFlags = pf.ChangePathFlags,
	GetStepLen = pf.GetStepLen,
	SetStepLen = pf.SetStepLen,
	SetSpeed = pf.SetSpeed,
	GetSpeed = pf.GetSpeed,
	SetMoveSpeed = pf.SetMoveSpeed,
	GetMoveSpeed = pf.GetMoveSpeed,
	GetMoveAnim = pf.GetMoveAnim,
	SetMoveAnim = pf.SetMoveAnim,
	GetWaitAnim = pf.GetWaitAnim,
	SetWaitAnim = pf.SetWaitAnim,
	ClearMoveAnim = pf.ClearMoveAnim,
	GetMoveTurnAnim = pf.GetMoveTurnAnim,
	SetMoveTurnAnim = pf.SetMoveTurnAnim,
	GetRotationTime = pf.GetRotationTime,
	SetRotationTime = pf.SetRotationTime,
	GetRotationSpeed = pf.GetRotationSpeed,
	SetRotationSpeed = pf.SetRotationSpeed,
	PathEndsBlocked = pf.PathEndsBlocked,
	SetDestlockRadius = pf.SetDestlockRadius,
	GetDestlockRadius = pf.GetDestlockRadius,
	GetDestlock = pf.GetDestlock,
	RemoveDestlock = pf.RemoveDestlock,
	GetDestination = pf.GetDestination,
	SetCollisionRadius = pf.SetCollisionRadius,
	GetCollisionRadius = pf.GetCollisionRadius,
	RestrictArea = pf.RestrictArea,
	GetRestrictArea = pf.GetRestrictArea,
	CheckPassable = pf.CheckPassable,

	GetPath = pf.GetPath,
	GetPathLen = pf.GetPathLen,
	GetPathPointCount = pf.GetPathPointCount,
	GetPathPoint = pf.GetPathPoint,
	SetPathPoint = pf.SetPathPoint,
	IsPathPartial = pf.IsPathPartial,
	GetPathHash = pf.GetPathHash,
	PopPathPoint = pf.PopPathPoint,

	SetPfClass = pf.SetPfClass,
	GetPfClass = pf.GetPfClass,
	
	Step = pf.Step,
	ResolveGotoTarget = pf.ResolveGotoTarget,
	ResolveGotoTargetXYZ = pf.ResolveGotoTargetXYZ,

	collision_radius = false,
	collision_radius_mod = 1000, -- used to auto-calculate the collision radius based on the radius.
	radius = 1 * guim,
	forced_collision_radius = false,
	forced_destlock_radius = false,
	outside_pathfinder = false,
	outside_pathfinder_reasons = false,
	
	last_move_time = 0,
	last_move_counter = 0,
}

--- Defines constants for various pathfinding status values.
---
--- @field pfFinished integer Pathfinding has finished successfully.
--- @field pfTunnel integer Pathfinding has encountered a tunnel.
--- @field pfFailed integer Pathfinding has failed.
--- @field pfStranded integer Pathfinding has stranded the entity.
--- @field pfDestLocked integer Pathfinding has encountered a destination lock.
--- @field pfOutOfPath integer Pathfinding has run out of path.
local pfSleep = Sleep
local pfFinished = const.pfFinished
local pfTunnel = const.pfTunnel
local pfFailed = const.pfFailed
local pfStranded = const.pfStranded
local pfDestLocked = const.pfDestLocked
local pfOutOfPath = const.pfOutOfPath

--- Returns a string representation of the given pathfinding status value.
---
--- @param status integer The pathfinding status value to get the text representation for.
--- @return string The text representation of the pathfinding status.
function GetPFStatusText(status)
	if type(status) ~= "number" then
		return ""
	elseif status >= 0 then
		return "Moving"
	elseif status == pfFinished then
		return "Finished"
	elseif status == pfTunnel then
		return "Tunnel"
	elseif status == pfFailed then
		return "Failed"
	elseif status == pfStranded then
		return "Stranded"
	elseif status == pfDestLocked then
		return "DestLocked"
	elseif status == pfOutOfPath then
		return "OutOfPath"
	end
	return ""
end

--- Initializes the entity associated with the Movable object.
---
--- This function sets the move and wait animations for the entity based on the available states. If no walk animation is available, it sets the move animation to "idle" and the step length to a default value.
---
--- @param self Movable The Movable object being initialized.
function Movable:InitEntity()
	if not IsValidEntity(self:GetEntity()) then
		return
	end
	if self:HasState("walk") then
		self:SetMoveAnim("walk")
	elseif self:HasState("moveWalk") then
		self:SetMoveAnim("moveWalk")
	elseif not self:HasState(self:GetMoveAnim() or -1) and self:HasState("idle") then
		-- temp move stub in case that there isn't any walk anim
		self:SetMoveAnim("idle")
		self:SetStepLen(guim)
	end
	if self:HasState("idle") then
		self:SetWaitAnim("idle")
	end
end

--- Initializes the Movable object and its associated entity.
---
--- This function sets up the move and wait animations for the entity, and initializes the pathfinding properties of the Movable object.
---
--- @param self Movable The Movable object being initialized.
function Movable:Init()
	self:InitEntity()
	self:InitPathfinder()
end

--- Initializes the pathfinding properties of the Movable object.
---
--- This function sets the pathfinding flags, updates the pathfinding class, and updates the pathfinding radius for the Movable object.
---
--- @param self Movable The Movable object being initialized.
function Movable:InitPathfinder()
	self:ChangePathFlags(self.pfflags)
	self:UpdatePfClass()
	self:UpdatePfRadius()
end

local efPathExecObstacle = const.efPathExecObstacle
local efResting = const.efResting
local pfStep = pf.Step
local pfStop = pf.Stop

--- Clears the current path of the Movable object.
---
--- If the Movable object is outside the pathfinder, this function simply returns. Otherwise, it stops the pathfinding for the Movable object.
---
--- @param self Movable The Movable object whose path is being cleared.
function Movable:ClearPath()
	if self.outside_pathfinder then
		return
	end
	return pfStop(self)
end

if Platform.asserts then

--- Moves the Movable object one step along its current path.
---
--- This function asserts that the Movable object is not outside the pathfinder, and then calls the `pf.Step` function to move the object one step along its current path.
---
--- @param self Movable The Movable object to be moved.
--- @param ... any Additional arguments to be passed to the `pf.Step` function.
--- @return any The return value of the `pf.Step` function.
function Movable:Step(...)
	assert(not self.outside_pathfinder)
	return pfStep(self, ...)
end

end -- Platform.asserts


--- Removes the Movable object from the pathfinder.
---
--- This function clears the current path of the Movable object, removes any destlock, updates the pathfinding radius, and clears the pathfinding execution and resting flags. It then sets the `outside_pathfinder` flag to `true`, effectively making the Movable object invisible to the pathfinder.
---
--- @param self Movable The Movable object to be removed from the pathfinder.
--- @param forced boolean (optional) If `true`, the function will remove the Movable object from the pathfinder regardless of its current state.
function Movable:ExitPathfinder(forced)
	-- makes the unit invisible to the pathfinder
	if not forced and self.outside_pathfinder then
		return
	end
	self:ClearPath()
	self:RemoveDestlock()
	self:UpdatePfRadius()
	self:ClearEnumFlags(efPathExecObstacle | efResting)
	self.outside_pathfinder = true
end

--- Adds the Movable object to the pathfinder.
---
--- This function sets the `outside_pathfinder` flag to `nil`, effectively making the Movable object visible to the pathfinder. It then updates the pathfinding radius and sets the pathfinding execution and resting flags.
---
--- @param self Movable The Movable object to be added to the pathfinder.
--- @param forced boolean (optional) If `true`, the function will add the Movable object to the pathfinder regardless of its current state.
function Movable:EnterPathfinder(forced)
	if not forced and not self.outside_pathfinder then
		return
	end
	self.outside_pathfinder = nil
	self:UpdatePfRadius()
	self:SetEnumFlags(efPathExecObstacle & GetClassEnumFlags(self) | efResting)
end

--- Adds a reason for the Movable object to be considered outside the pathfinder.
---
--- This function adds a new reason to the `outside_pathfinder_reasons` table for the Movable object. If the reason already exists, the function will return without doing anything. If the Movable object is not currently considered outside the pathfinder, the function will call `Movable:ExitPathfinder()` to mark the object as outside the pathfinder.
---
--- @param self Movable The Movable object to add the reason to.
--- @param reason string The reason to add for the Movable object being outside the pathfinder.
function Movable:AddOutsidePathfinderReason(reason)
	local reasons = self.outside_pathfinder_reasons or {}
	if reasons[reason] then return end
	reasons[reason] = true
	if not self.outside_pathfinder then
		self:ExitPathfinder()
	end
	self.outside_pathfinder_reasons = reasons
end

--- Removes a reason for the Movable object to be considered outside the pathfinder.
---
--- This function removes a reason from the `outside_pathfinder_reasons` table for the Movable object. If the reason does not exist, the function will assert an error unless `ignore_error` is `true`. If the `outside_pathfinder_reasons` table becomes empty after removing the reason, the function will call `Movable:EnterPathfinder()` to mark the object as inside the pathfinder.
---
--- @param self Movable The Movable object to remove the reason from.
--- @param reason string The reason to remove for the Movable object being outside the pathfinder.
--- @param ignore_error boolean (optional) If `true`, the function will not assert an error if the reason does not exist.
function Movable:RemoveOutsidePathfinderReason(reason, ignore_error)
	if not IsValid(self) then return end
	local reasons = self.outside_pathfinder_reasons
	assert(ignore_error or reasons and reasons[reason], "Unit trying to remove invalid outside_pathfinder reason: "..reason)
	if not reasons or not reasons[reason] then return end
	reasons[reason] = nil
	if next(reasons) then
		self.outside_pathfinder_reasons = reasons
		return
	end
	self:EnterPathfinder()
	self.outside_pathfinder_reasons = nil
end

--- Changes the destination lock radius of the Movable object.
---
--- This function sets the `forced_destlock_radius` property of the Movable object to the provided `forced_destlock_radius` value. It then calls the `Movable:UpdatePfRadius()` function to update the pathfinding radius of the object.
---
--- @param self Movable The Movable object to change the destination lock radius for.
--- @param forced_destlock_radius number The new destination lock radius to set for the Movable object.
function Movable:ChangeDestlockRadius(forced_destlock_radius)
	if self.forced_destlock_radius == forced_destlock_radius then
		return
	end
	self.forced_destlock_radius = forced_destlock_radius
	self:UpdatePfRadius()
end

--- Removes the forced destination lock radius for the Movable object.
---
--- This function removes the `forced_destlock_radius` property of the Movable object, effectively restoring the default destination lock radius. It then calls the `Movable:UpdatePfRadius()` function to update the pathfinding radius of the object.
---
--- @param self Movable The Movable object to restore the destination lock radius for.
--- @param forced_destlock_radius number The destination lock radius to restore for the Movable object.
function Movable:RestoreDestlockRadius(forced_destlock_radius)
	if self.forced_destlock_radius ~= forced_destlock_radius then
		return
	end
	self.forced_destlock_radius = nil
	self:UpdatePfRadius()
end

--- Changes the collision radius of the Movable object.
---
--- This function sets the `forced_collision_radius` property of the Movable object to the provided `forced_collision_radius` value. It then calls the `Movable:UpdatePfRadius()` function to update the pathfinding radius of the object.
---
--- @param self Movable The Movable object to change the collision radius for.
--- @param forced_collision_radius number The new collision radius to set for the Movable object.
function Movable:ChangeCollisionRadius(forced_collision_radius)
	if self.forced_collision_radius == forced_collision_radius then
		return
	end
	self.forced_collision_radius = forced_collision_radius
	self:UpdatePfRadius()
end

--- Removes the forced collision radius for the Movable object.
---
--- This function removes the `forced_collision_radius` property of the Movable object, effectively restoring the default collision radius. It then calls the `Movable:UpdatePfRadius()` function to update the pathfinding radius of the object.
---
--- @param self Movable The Movable object to restore the collision radius for.
--- @param forced_collision_radius number The collision radius to restore for the Movable object.
function Movable:RestoreCollisionRadius(forced_collision_radius)
	if self.forced_collision_radius ~= forced_collision_radius then
		return
	end
	self.forced_collision_radius = nil
	self:UpdatePfRadius()
end

--- Updates the pathfinding radius of the Movable object.
---
--- This function updates the destination lock radius and collision radius of the Movable object based on the `forced_collision_radius` and `forced_destlock_radius` properties. If the Movable object is outside the pathfinder, the destination lock radius and collision radius are set to 0. Otherwise, the destination lock radius is set to the `forced_destlock_radius` or the object's radius, and the collision radius is set to the `forced_collision_radius` or the object's collision radius multiplied by the `collision_radius_mod` property.
---
--- @param self Movable The Movable object to update the pathfinding radius for.
function Movable:UpdatePfRadius()
	local forced_collision_radius, forced_destlock_radius = self.forced_collision_radius, self.forced_destlock_radius
	if self.outside_pathfinder then
		forced_collision_radius, forced_destlock_radius = 0, 0
	end
	local radius = self:GetRadius()
	self:SetDestlockRadius(forced_destlock_radius or radius)
	self:SetCollisionRadius(forced_collision_radius or self.collision_radius or radius * self.collision_radius_mod / 1000)
end

--- Returns the pathfinding class data for the Movable object.
---
--- This function retrieves the pathfinding class data for the Movable object by calling `self:GetPfClass()` and using the result to index into the `pathfind` table. The returned data represents the properties and settings for the pathfinding class associated with the Movable object.
---
--- @return table The pathfinding class data for the Movable object.
function Movable:GetPfClassData()
	return pathfind[self:GetPfClass() + 1]
end

--- Returns the pathfinding spheroid radius for the Movable object.
---
--- This function retrieves the pathfinding class data for the Movable object and uses the `pass_grid` property to determine the appropriate spheroid radius. If the `pass_grid` is set to `PF_GRID_NORMAL`, the `const.passSpheroidWidth` value is returned. Otherwise, the `const.passLargeSpheroidWidth` value is returned.
---
--- @return number The pathfinding spheroid radius for the Movable object.
function Movable:GetPfSpheroidRadius()
	local pfdata = self:GetPfClassData()
	local pass_grid = pfdata and pfdata.pass_grid or PF_GRID_NORMAL
	return pass_grid == PF_GRID_NORMAL and const.passSpheroidWidth or const.passLargeSpheroidWidth
end

if config.TraceEnabled then
--- Sets the speed of the Movable object.
---
--- This function sets the speed of the Movable object by calling the `pf.SetSpeed()` function and passing the Movable object and the new speed as arguments.
---
--- @param self Movable The Movable object to set the speed for.
--- @param speed number The new speed to set for the Movable object.
function Movable:SetSpeed(speed)
	pf.SetSpeed(self, speed)
end
end

--- Called when a command to start moving the Movable object is received.
---
--- This function is called when a command is received to start moving the Movable object. It first calls `self:OnStopMoving()` to stop any current movement, and then clears the path of the Movable object by calling `self:ClearPath()`. This ensures that the Movable object is ready to start a new movement command.
---
--- @param self Movable The Movable object that is starting a new movement command.
function Movable:OnCommandStart()
	self:OnStopMoving()
	if IsValid(self) then
		self:ClearPath()
	end
end

--- Finds a path for the Movable object to follow.
---
--- This function uses the `pf.FindPath()` function to find a path for the Movable object to follow. It will continue to call `pf.FindPath()` until a status code less than or equal to 0 is returned, indicating that the path has been found or an error has occurred.
---
--- @param self Movable The Movable object to find a path for.
--- @param ... any Additional arguments to pass to `pf.FindPath()`.
--- @return number, any The status code returned by `pf.FindPath()`, and any additional return values.
function Movable:FindPath(...)
	local pfFindPath = pf.FindPath
	while true do
		local status, partial = pfFindPath(self, ...)
		if status <= 0 then
			return status, partial
		end
		Sleep(status)
	end
end

--- Checks if the Movable object has a path to follow.
---
--- This function calls `Movable:FindPath()` to find a path for the Movable object. If the status code returned is 0, indicating that a path has been found, this function returns `true`. Otherwise, it returns `false`.
---
--- @param self Movable The Movable object to check for a path.
--- @param ... any Additional arguments to pass to `Movable:FindPath()`.
--- @return boolean `true` if the Movable object has a path, `false` otherwise.
function Movable:HasPath(...)
	local status = self:FindPath(...)
	return status == 0
end

--- Finds the length of the path for the Movable object.
---
--- This function checks if the Movable object has a path to follow by calling `Movable:HasPath()`. If a path is found, it returns the length of the path by calling `pf.GetPathLen()`.
---
--- @param self Movable The Movable object to find the path length for.
--- @param ... any Additional arguments to pass to `Movable:HasPath()`.
--- @return number The length of the path, or `nil` if no path is found.
function Movable:FindPathLen(...)
	if self:HasPath(...) then
		return pf.GetPathLen(self)
	end
end

local Sleep = Sleep
--- Sleeps for the specified time.
---
--- This function is a wrapper around the built-in `Sleep()` function, which pauses the current coroutine for the specified number of seconds.
---
--- @param self Movable The Movable object.
--- @param time number The number of seconds to sleep.
--- @return number The number of seconds slept.
function Movable:MoveSleep(time)
	return Sleep(time)
end

--- Checks if the Movable object can start moving.
---
--- This function is called to determine if the Movable object can start moving based on the provided status code. The `AutoResolveMethods.CanStartMove` value is used to determine the logic for this check.
---
--- @param self Movable The Movable object.
--- @param status number The status code returned by `Movable:Step()`.
--- @return boolean `true` if the Movable object can start moving, `false` otherwise.
AutoResolveMethods.CanStartMove = "and"
function Movable:CanStartMove(status)
	return status >= 0 or status == pfTunnel or status == pfStranded or status == pfDestLocked or status == pfOutOfPath
end

--- Attempts to continue the movement of the Movable object after encountering a specific status code.
---
--- This function is called when the `Movable:Step()` function returns a status code indicating that the movement has encountered a special condition, such as a tunnel, a stranded state, a locked destination, or being out of the path. The function attempts to handle these conditions and continue the movement if possible.
---
--- @param self Movable The Movable object.
--- @param status number The status code returned by `Movable:Step()`.
--- @param ... any Additional arguments to pass to the fallback functions.
--- @return boolean `true` if the movement was able to continue, `false` otherwise.
function Movable:TryContinueMove(status, ...)
	if status == pfTunnel then
		if self:TraverseTunnel() then
			return true
		end
	elseif status == pfStranded then
		if self:OnStrandedFallback(...) then
			return true
		end
	elseif status == pfDestLocked then
		if self:OnDestlockedFallback(...) then
			return true
		end
	elseif status == pfOutOfPath then
		if self:OnOutOfPathFallback(...) then
			return true
		end
	end
end

---
--- Moves the Movable object to a specified destination.
---
--- This function is responsible for handling the movement of the Movable object. It first prepares the movement by calling `Movable:PrepareToMove()`. If there is an error during the preparation, the function returns `false` and the status `pfFailed`.
---
--- If the preparation is successful, the function calls `Movable:Step()` to perform the movement. If the Movable object cannot start moving based on the returned status, the function returns the status.
---
--- If the Movable object can start moving, the function calls `Movable:OnStartMoving()` and then enters a loop. In the loop, the function checks the status returned by `Movable:Step()`. If the status is greater than 0, the function calls `Movable:OnGotoStep()` to handle the step. If the step is interrupted, the loop is broken. Otherwise, the function calls `Movable:MoveSleep()` to pause the current coroutine for the specified duration.
---
--- If the status returned by `Movable:Step()` is not greater than 0, the function calls `Movable:TryContinueMove()` to attempt to continue the movement. If the attempt is unsuccessful, the loop is broken.
---
--- Finally, the function calls `Movable:OnStopMoving()` and returns the status of the movement.
---
--- @param self Movable The Movable object.
--- @param ... any Additional arguments to pass to the movement functions.
--- @return boolean `true` if the movement was successful, `false` otherwise.
--- @return number The status of the movement.
function Movable:Goto(...)
	local err = self:PrepareToMove(...)
	if err then
		return false, pfFailed
	end
	local status = self:Step(...)
	if not self:CanStartMove(status) then
		return status == pfFinished, status
	end
	self:OnStartMoving(...)
	local pfSleep = self.MoveSleep
	while true do
		if status > 0 then
			if self:OnGotoStep(status) then
				break -- interrupted
			end
			pfSleep(self, status)
		elseif not self:TryContinueMove(status, ...) then
			break
		end
		status = self:Step(...)
	end
	self:OnStopMoving(status, ...)
	return status == pfFinished, status
end

AutoResolveMethods.OnGotoStep = "or"
Movable.OnGotoStep = empty_func

---
--- Traverses a tunnel in the path of the Movable object.
---
--- This function is responsible for handling the traversal of a tunnel in the path of the Movable object. It first retrieves the tunnel and any associated parameters from the pathfinding system using `pf.GetTunnel()`. If no tunnel is found, the function calls `Movable:OnTunnelMissingFallback()` to handle the missing tunnel.
---
--- If a tunnel is found, the function calls `tunnel:TraverseTunnel()` to attempt to traverse the tunnel. If the traversal is unsuccessful, the function clears the path and returns `false`.
---
--- If the traversal is successful, the function calls `Movable:OnTunnelTraversed()` to notify the Movable object that a tunnel has been traversed.
---
--- @param self Movable The Movable object.
--- @return boolean `true` if the tunnel was traversed successfully, `false` otherwise.
function Movable:TraverseTunnel()
	local tunnel, param = pf.GetTunnel(self)
	if not tunnel then
		return self:OnTunnelMissingFallback()
	elseif not tunnel:TraverseTunnel(self, self:GetPathPoint(-1), param) then
		self:ClearPath()
		return false
	end
	
	self:OnTunnelTraversed(tunnel)
	return true
end

AutoResolveMethods.OnTunnelTraversed = "call"
-- function Movable:OnTunnelTraversed(tunnel)
Movable.OnTunnelTraversed = empty_func

---
--- Handles the fallback behavior when a tunnel is missing in the path of the Movable object.
---
--- This function is called when the pathfinding system is unable to find a tunnel that is part of the Movable object's path. It first checks if the game is in developer mode, and if so, it adds some debug information to the scene, including the current position of the Movable object, the next position in the path, and a message indicating that a tunnel is missing.
---
--- After adding the debug information, the function asserts that the tunnel is missing and sleeps for 100 milliseconds. It then clears the Movable object's path and returns `true` to indicate that the fallback behavior has been handled.
---
--- @param self Movable The Movable object.
--- @return boolean `true` to indicate that the fallback behavior has been handled.
function Movable:OnTunnelMissingFallback()
	if Platform.developer then
		local pos = self:GetPos()
		local next_pos = self:GetPathPoint(-1)
		local text_pos = ValidateZ(pos, 3*guim)
		DbgAddSegment(pos, text_pos, red)
		if next_pos then
			DbgAddVector(pos + point(0, 0, guim/2), next_pos - pos, yellow)
		end
		DbgAddText("Tunnel missing!", text_pos, red)
		StoreErrorSource("silent", pos, "Tunnel missing!")
	end
	assert(false, "Tunnel missing!")
	Sleep(100)
	self:ClearPath()
	return true
end

---
--- Handles the fallback behavior when the Movable object is out of its path.
---
--- This function is called when the pathfinding system is unable to find a valid path for the Movable object. It first asserts that the unit is out of path, then sleeps for 100 milliseconds. It then clears the Movable object's path and returns `true` to indicate that the fallback behavior has been handled.
---
--- @param self Movable The Movable object.
--- @return boolean `true` to indicate that the fallback behavior has been handled.
function Movable:OnOutOfPathFallback()
	assert(false, "Unit out of path!")
	Sleep(100)
	self:ClearPath()
	return true
end

AutoResolveMethods.PickPfClass = "or"
Movable.PickPfClass = empty_func

---
--- Updates the pathfinding class for the Movable object.
---
--- This function first calls the `PickPfClass()` method to determine the appropriate pathfinding class for the Movable object. If the `PickPfClass()` method returns a value, it is used as the pathfinding class. Otherwise, the `pfclass` property of the Movable object is used.
---
--- The function then calls the `SetPfClass()` method to set the pathfinding class for the Movable object.
---
--- @param self Movable The Movable object.
--- @return boolean `true` if the pathfinding class was successfully updated, `false` otherwise.
function Movable:UpdatePfClass()
	local pfclass = self:PickPfClass() or self.pfclass
	return self:SetPfClass(pfclass)
end

---
--- Handles the fallback behavior when an infinite move loop is detected for the Movable object.
---
--- This function is called when the `CheckInfinteMove()` function detects that the Movable object is in an infinite move loop. It sleeps for 100 milliseconds to allow the game to recover from the infinite loop.
---
--- @param self Movable The Movable object.
function Movable:OnInfiniteMoveDetected()
	Sleep(100)
end

---
--- Checks if the Movable object is in an infinite move loop.
---
--- This function is called before the Movable object attempts to move. It checks if the current move is part of an infinite loop by tracking the time and number of consecutive moves. If the Movable object has attempted to move 100 times in the same time period, the function asserts that an infinite move loop has been detected and calls the `OnInfiniteMoveDetected()` function.
---
--- @param self Movable The Movable object.
--- @param dest table The destination position for the move.
--- @param ... any Additional arguments passed to the move function.
function Movable:CheckInfinteMove(dest, ...)
	local time = GameTime() + RealTime()
	if time ~= self.last_move_time then
		self.last_move_counter = nil
		self.last_move_time = time
	elseif self.last_move_counter == 100 then
		assert(false, "Infinte move loop!")
		self:OnInfiniteMoveDetected()
	else
		self.last_move_counter = self.last_move_counter + 1
	end
end

AutoResolveMethods.PrepareToMove = "or"
---
--- Checks if the Movable object is in an infinite move loop and calls the `OnInfiniteMoveDetected()` function if so.
---
--- This function is called before the Movable object attempts to move. It checks if the current move is part of an infinite loop by tracking the time and number of consecutive moves. If the Movable object has attempted to move 100 times in the same time period, the function asserts that an infinite move loop has been detected and calls the `OnInfiniteMoveDetected()` function.
---
--- @param self Movable The Movable object.
--- @param dest table The destination position for the move.
--- @param ... any Additional arguments passed to the move function.
function Movable:PrepareToMove(dest, ...)
	self:CheckInfinteMove(dest, ...)
end

AutoResolveMethods.OnStartMoving = true
Movable.OnStartMoving = empty_func --function Movable:OnStartMoving(dest, ...)

AutoResolveMethods.OnStopMoving = true
Movable.OnStopMoving = empty_func --function Movable:OnStopMoving(status, dest, ...)

---
--- Handles the fallback behavior when the Movable object is stranded and cannot move to the specified destination.
---
--- This function is called when the Movable object is unable to move to the specified destination. It allows you to implement custom logic to handle the stranded situation.
---
--- @param self Movable The Movable object.
--- @param dest table The destination position for the move.
--- @param ... any Additional arguments passed to the move function.
function Movable:OnStrandedFallback(dest, ...)
end

---
--- Handles the fallback behavior when the Movable object is unable to move to the specified destination.
---
--- This function is called when the Movable object is unable to move to the specified destination. It allows you to implement custom logic to handle the situation where the Movable object is stranded and cannot reach the specified destination.
---
--- @param self Movable The Movable object.
--- @param dest table The destination position for the move.
--- @param ... any Additional arguments passed to the move function.
function Movable:OnDestlockedFallback(dest, ...)
end

local pfmDestlock = const.pfmDestlock
local pfmDestlockSmart = const.pfmDestlockSmart
local pfmDestlockAll = pfmDestlock + pfmDestlockSmart

---
--- Attempts to move the Movable object to the specified destination without getting stuck due to destination locking.
---
--- This function is a wrapper around the `Goto` function that handles cases where the Movable object's path is blocked due to destination locking. It temporarily disables the destination locking flags, performs the move, and then restores the original flags.
---
--- @param self Movable The Movable object.
--- @param ... any Arguments passed to the `Goto` function.
--- @return boolean The result of the `Goto` function call.
function Movable:Goto_NoDestlock(...)
	local flags = self:GetPathFlags(pfmDestlockAll)
	if flags == 0 then
		return self:Goto(...)
	end
	self:ChangePathFlags(0, flags)
	if flags == pfmDestlock then
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlock, 0) end
		end)
	elseif flags == pfmDestlockSmart then
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlockSmart, 0) end
		end)
	else
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlockAll, 0) end
		end)
	end
	local res = self:Goto(...)
	self:PopDestructor()
	self:ChangePathFlags(flags, 0)
	return res
end

---
--- Interrupts the current path of the Movable object.
---
--- This function sets the `pfInterrupt` path flag on the Movable object, which will cause the current path to be interrupted. This can be useful when you need to cancel the current path and start a new one.
---
--- @param self Movable The Movable object.
function Movable:InterruptPath()
	pf.ChangePathFlags(self, const.pfInterrupt)
end

---
--- Persists the specified permanents for the path finding system.
---
--- This function is called when the game is saved, and it stores the specified path finding functions in the permanents table so that they can be restored when the game is loaded.
---
--- @param permanents table The table of permanents to be persisted.
--- @param direction string The direction of the persistence (e.g. "save" or "load").
---
function OnMsg.PersistGatherPermanents(permanents, direction)
	permanents["pf.Step"] = pf.Step
	permanents["pf.FindPath"] = pf.FindPath
	permanents["pf.RestrictArea"] = pf.RestrictArea
end


----- PFTunnel

---
--- Defines a class for a PFTunnel object, which is a part of the path finding system.
---
--- The PFTunnel class has the following properties:
---
--- - `dbg_tunnel_color`: The color used for debugging the tunnel.
--- - `dbg_tunnel_zoffset`: The z-offset used for debugging the tunnel.
---
--- This class is used internally by the path finding system and is not intended to be used directly by the user.
---
DefineClass.PFTunnel = {
	__parents = { "Object" },
	dbg_tunnel_color = const.clrGreen,
	dbg_tunnel_zoffset = 0,
}

---
--- Removes the PFTunnel object from the path finding system.
---
--- This function is called when the PFTunnel object is no longer needed, and it removes the tunnel from the path finding system.
---
function PFTunnel:Done()
	self:RemovePFTunnel()
end

---
--- Adds a PFTunnel object to the path finding system.
---
--- This function is called to add a PFTunnel object to the path finding system. The PFTunnel object represents a tunnel that can be used by units during path finding.
---
--- @param self PFTunnel The PFTunnel object to be added.
--- @return boolean True if the PFTunnel was successfully added, false otherwise.
---
function PFTunnel:AddPFTunnel()
end

---
--- Removes the PFTunnel object from the path finding system.
---
--- This function is called when the PFTunnel object is no longer needed, and it removes the tunnel from the path finding system.
---
function PFTunnel:RemovePFTunnel()
	pf.RemoveTunnel(self)
end

---
--- Traverses a PFTunnel object, setting the unit's position to the end point of the tunnel.
---
--- @param unit table The unit that is traversing the tunnel.
--- @param end_point table The end point of the tunnel.
--- @param param table Additional parameters for the tunnel traversal.
--- @return boolean True if the tunnel traversal was successful, false otherwise.
---
function PFTunnel:TraverseTunnel(unit, end_point, param)
	unit:SetPos(end_point)
	return true
end

---
--- Attempts to add the PFTunnel object to the path finding system.
---
--- This function is a wrapper around the `PFTunnel:AddPFTunnel()` function, which adds the PFTunnel object to the path finding system. If the addition is successful, this function returns `true`, otherwise it returns `false`.
---
--- @return boolean True if the PFTunnel was successfully added, false otherwise.
---
function PFTunnel:TryAddPFTunnel()
	return self:AddPFTunnel()
end

function OnMsg.LoadGame()
	MapForEach("map", "PFTunnel", function(obj) return obj:TryAddPFTunnel() end)
end

----

---
--- Checks if a unit is exactly on a passable level of the terrain.
---
--- This function checks if the given unit is positioned exactly on a passable level of the terrain. It uses the `terrain.FindPassableZ` function to determine the passable z-coordinate at the unit's current x and y coordinates, and then checks if the unit's z-coordinate matches the passable z-coordinate.
---
--- @param unit table The unit to check.
--- @return boolean True if the unit is exactly on a passable level, false otherwise.
---
function IsExactlyOnPassableLevel(unit)
	local x, y, z = unit:GetVisualPosXYZ()
	return terrain.FindPassableZ(x, y, z, unit:GetPfClass(), 0, 0)
end

----

---
--- Callback function for debugging path finding.
---
--- This function is called when the path finding system is debugging a path for a movable object. It creates a debug object to visualize the path and provides information about the path, such as the distance to the target, the path length, and the status of the path finding.
---
--- @param status number The status of the path finding operation.
--- @param ... any Additional parameters passed to the callback function, which may include the target object or position.
--- @return nil
---
function Movable:FindPathDebugCallback(status, ...)
	local params = {...}
	local target = ...
	local dist, target_str = 0, ""
	local target_pos
	if IsPoint(target) then
		target_pos = target
		dist = self:GetDist2D(target)
		target_str = tostring(target)
	elseif IsValid(target) then
		target_pos = target:GetVisualPos()
		dist = self:GetDist2D(target)
		target_str = string.format("%s:%d", target.class, target.handle)
	elseif type(target) == "table" then
		target_pos = target[1]
		dist = self:GetDist2D(target[1])
		for i = 1, #target do
			local p = target[i]
			local d = self:GetDist2D(p)
			if i == 1 or d < dist then
				dist = d
				target_pos = p
			end
			target_str = target_str .. tostring(p)
		end
	end
	local o = DebugPathObj:new{}
	o:SetPos(self:GetVisualPos())
	o:ChangeEntity(self:GetEntity())
	o:SetScale(30)
	o:Face(target_pos)
	o.obj = self
	o.command = self.command
	o.target = target
	o.target_pos = target_pos
	o.params = params
	o.txt = string.format(
		"handle:%d %15s %20s, dist:%4dm, status %d, pathlen:%4.1fm, restrict_r:%.1fm, target:%s",
		self.handle, self.class, self.command, dist/guim, status, 1.0*pf.GetPathLen(self)/guim, 1.0*self:GetRestrictArea()/guim, target_str)
	printf("Path debug: time:%d, %s", GameTime(), o.txt)
	pf.SetPfClass(o, self:GetPfClass())
	pf.ChangePathFlags(o, self.pfflags)
	pf.SetCollisionRadius(o, self:GetCollisionRadius())
	pf.SetDestlockRadius(o, self:GetRadius())
	pf.RestrictArea(o, self:GetRestrictArea())
	--TogglePause()
	--ViewObject(self)
end
	
-- !DebugPathObj.target_pos
-- !DebugPathObj.command
-- SelectedObj:DrawPath()
---
--- Defines a class `DebugPathObj` that inherits from the `Movable` class.
--- This class is used for debugging path-finding operations.
---
--- @class DebugPathObj
--- @field flags table Flags for the object, including `efSelectable = true`.
--- @field entity string The entity type for the object, set to `"WayPoint"`.
--- @field obj boolean The object being debugged.
--- @field command string The command associated with the object.
--- @field target boolean The target of the object.
--- @field target_pos boolean The position of the target.
--- @field params table Parameters for the path-finding operation.
--- @field restrict_pos boolean The restricted position for the object.
--- @field restrict_radius number The radius of the restricted area.
--- @field txt string A text description of the object and its path-finding information.
--- @field FindPathDebugCallback function A callback function for finding the path.
--- @function DrawPath
---   Finds the path for the object and draws a waypoint path to the target position.
DefineClass.DebugPathObj = {
	__parents = { "Movable" },
	flags = { efSelectable = true },
	entity = "WayPoint",
	obj = false,
	command = "",
	target = false,
	target_pos = false,
	params = false,
	restrict_pos = false,
	restrict_radius = 0,
	txt = "",
	FindPathDebugCallback = empty_func,
	DrawPath = function(self)
		pf.FindPath(self, table.unpack(self.params))
		DrawWayPointPath(self, self.target_pos)
	end,
}

-- generate clusters of objects around "leaders" (selected from the objs) where each obj is no more than dist_threshold apart from its leader
---
--- Generates clusters of objects around "leaders" (selected from the `objs` parameter) where each object is no more than `dist_threshold` apart from its leader.
---
--- @param objs table A table of objects to be clustered.
--- @param dist_threshold number The maximum distance threshold for an object to be considered part of a cluster.
--- @param func function A callback function to be called for each object in a cluster.
--- @param ... any Additional arguments to be passed to the callback function.
function LeaderClustering(objs, dist_threshold, func, ...)
	local other_leaders -- objs[1] is always a leader but not included here
	for _, obj in ipairs(objs) do
		-- find the nearest leader
		local leader = objs[1]
		local dist = leader:GetDist2D(obj)
		for _, leader2 in ipairs(other_leaders) do
			local dist2 = leader2:GetDist2D(obj)
			if dist > dist2 then
				leader, dist = leader2, dist2
			end
		end
		if dist > dist_threshold then -- new leader
			leader = obj
			dist = 0
			other_leaders = other_leaders or {}
			other_leaders[#other_leaders + 1] = leader
		end
		func(obj, leader, dist, ...)
	end
end

-- splits objs in clusters and moves the center of each cluster close to the destination, keeping relative positions of objs within the cluster
---
--- Generates clusters of objects around "leaders" (selected from the `objs` parameter) where each object is no more than `dist_threshold` apart from its leader.
---
--- @param objs table A table of objects to be clustered.
--- @param dist_threshold number The maximum distance threshold for an object to be considered part of a cluster.
--- @param dest point The destination point to move the clusters towards.
--- @param func function A callback function to be called for each object in a cluster.
--- @param ... any Additional arguments to be passed to the callback function.
function ClusteredDestinationOffsets(objs, dist_threshold, dest, func, ...)
	if #(objs or "") == 0 then return end
	local x0, y0, z0 = dest:xyz()
	local invalid_z = const.InvalidZ
	z0 = z0 or invalid_z
	if #objs == 1 then
		z0 = terrain.FindPassableZ(x0, y0, z0, objs[1].pfclass) or z0
		func(objs[1], x0, y0, z0, ...)
		return
	end
	local clusters = {}
	local base_x, base_y = 0, 0
	LeaderClustering(objs, dist_threshold, function(obj, leader, dist, clusters)
		local cluster = clusters[leader]
		if not cluster then
			cluster = { x = 0, y = 0, }
			clusters[leader] = cluster
			clusters[#clusters + 1] = cluster
		end
		local x, y = obj:GetPosXYZ()
		cluster.x = cluster.x + x
		cluster.y = cluster.y + y
		base_x = base_x + x
		base_y = base_y + y
		cluster[#cluster + 1] = obj
	end, clusters)
	base_x, base_y = base_x / #objs, base_y / #objs
	local offs = dist_threshold / 4
	for idx, cluster in ipairs(clusters) do
		local x, y = cluster.x / #cluster, cluster.y / #cluster
		-- move cluster center a bit in the direction of its relative position to the group
		local dx, dy = x - base_x, y - base_y
		local len = sqrt(dx * dx + dy * dy)
		if len > 0 then -- offset dest
			dx, dy = dx * offs / len, dy * offs / len
		end
		-- vector from cluster center to dest
		x, y = x0 - x + dx, y0 - y + dy
		for _, obj in ipairs(cluster) do
			local obj_x, obj_y, obj_z = obj:GetPosXYZ()
			local x1, y1, z1 = obj_x + x, obj_y + y, z0
			z1 = terrain.FindPassableZ(x1, y1, z1, obj.pfclass) or z1
			func(obj, x1, y1, z1, ...)
		end
	end
end

----

MapVar("PathTestObj", false)

---
--- Defines a class for a test path object, which is a movable object used for testing pathfinding.
---
--- The test path object has the following properties:
--- - `cofComponentAnim = false`: Disables component animation.
--- - `cofComponentInterpolation = false`: Disables component interpolation.
--- - `cofComponentCurvature = false`: Disables component curvature.
--- - `efPathExecObstacle = false`: Indicates that the object is not an obstacle for pathfinding.
--- - `efResting = false`: Indicates that the object is not resting.
--- - `efSelectable = false`: Indicates that the object is not selectable.
--- - `efVisible = false`: Indicates that the object is not visible.
--- - `pfflags = 0`: Sets the pathfinding flags to 0.
---
DefineClass.TestPathObj = {
	__parents = { "Movable" },
	flags = {
		cofComponentAnim = false, cofComponentInterpolation = false, cofComponentCurvature = false,
		efPathExecObstacle = false, efResting = false, efSelectable = false, efVisible = false,
	},
	pfflags = 0,
}

---
--- Returns a test path object, which is a movable object used for testing pathfinding.
---
--- The test path object is created and placed in the game world. After a short delay, the object is destroyed.
---
--- @return TestPathObj|false the test path object, or false if the object could not be created
---
function GetPathTestObj()
	if not IsValid(PathTestObj) then
		PathTestObj = PlaceObject("TestPathObj")
		CreateGameTimeThread(function()
			DoneObject(PathTestObj)
			PathTestObj = false
		end)
	end
	return PathTestObj
end

----

--[[ example usage
ClusteredDestinationOffsets(objs, dist_threshold, dest, function (obj, x, y, z)
	obj:SetCommand("GotoPos", point(x, y, z))
end)
--]]

--[[
DefineClass.Destblockers = 
{
	__parents = { "Object" },
	flags = { efResting = true },

	entity = "Guard_01",
}

DefineClass.PathTest = 
{
	__parents = { "Movable", "CommandObject" },
	entity = "Guard_01",
	Goto = function(self, ...)
		self:ChangePathFlags(const.pfmCollisionAvoidance)
		self:SetCollisionRadius(self:GetRadius() / 2)
		return Movable.Goto(self, ...)
	end,
}



function TestPath2()
	local o = GetObjects{classes = "PathTest"}[1]
	local target_pt = GetTerrainCursor()
	if not IsValid(o) then
		o = PlaceObject("PathTest")
	end
	o:SetPos(point(141754, 117046, 20000))
	o:SetCommand("Goto", point(132353, 125727, 20000))
end

function TestPath()
	local o = GetObjects{classes = "PathTest"}[1]
	local target_pt = GetTerrainCursor()
	if not IsValid(o) then
		o = PlaceObject("PathTest")
		o:SetPos(target_pt)
		target_pt = target_pt + point(1000, 0, 0)
	end
	o:SetCommand("Goto", target_pt)
end

function TestCollisionAvoid()
	GetObjects{classes = "PathTest"}:Destroy()
	CreateGameTimeThread(function()
		local pt = point(134941, 153366, 20000)
		
		for i = 0, 5 do
			local g1 = PathTest:new()
			g1:SetPos(pt+point(-6 * guim, i*2*guim))
			g1:SetCommand("Goto", g1:GetPos() + point(12*guim, 0))
			Sleep(200)

			local g1 = PathTest:new()
			g1:SetPos(pt+point(6 * guim, i*2*guim))
			g1:SetCommand("Goto", g1:GetPos() + point(-12*guim, 0))
			Sleep(200)
		end
	end)
end
]]
