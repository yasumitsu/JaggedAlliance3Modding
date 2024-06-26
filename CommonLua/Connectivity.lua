if not const.ConnectivitySupported then
	return
end

OnMsg.PostNewMapLoaded = ConnectivityResume
OnMsg.PostLoadGame = ConnectivityResume

if Platform.asserts then

    ---
    --- Tests the connectivity between a unit and a target position.
    ---
    --- @param unit Movable The unit to test connectivity for.
    --- @param target point The target position to test connectivity to.
    --- @param count number The number of times to test connectivity (default is 1).
    ---
    --- This function tests the connectivity between the given unit and target position using two different methods:
    --- 1. ConnectivityCheck: This method uses the Connectivity system to check if there is a path between the unit and target.
    --- 2. pf.HasPosPath: This method uses the pathfinding system to check if there is a path between the unit and target.
    ---
    --- The function prints the results of both methods, including whether a path was found and the time it took to perform the check.
    ---
    function TestConnectivity(unit, target, count)
        count = count or 1
        unit = unit or SelectedObj
        target = target or terrain.FindPassable(GetCursorPos())
        DbgClear()
        if not IsKindOf(unit, "Movable") then
            return
        end
        target = target or MapFindNearest(unit, "map", unit.class, function(obj)
            return obj ~= unit
        end)
        if not target then
            return
        end
        ConnectivityClear() -- test the uncached connectivity speed, as the cached one is practically zero.
        local stA = GetPreciseTicks(1000000)
        local pathA = ConnectivityCheck(unit, target) or false
        local timeA = GetPreciseTicks(1000000) - stA
        local stB = GetPreciseTicks(1000000)
        local pfclass, range, min_range, path_owner, restrict_area_radius, restrict_area
        local path_flags = const.pfmImpassableSource
        local pathB = pf.HasPosPath(unit, target, pfclass, range, min_range, path_owner, restrict_area_radius,
            restrict_area, path_flags) or false
        local timeB = GetPreciseTicks(1000000) - stB
        DbgAddSegment(unit, target)
        print("1 | path:", pathA, "| time:", timeA / 1000.0, "| ConnectivityCheck")
        print("2 | path:", pathB, "| time:", timeB / 1000.0, "| pf.HasPosPath")
        print("Linear dist 2D:", unit:GetDist2D(target))
    end

    ---
    --- Prints information about the connectivity patch for the given position and pathfinding class.
    ---
    --- @param pos point The position to get the connectivity patch information for.
    ---
    function TestConnectivityShowPatch(pos)
        hr.DbgAutoClearLimit = Max(20000, hr.DbgAutoClearLimit)
        hr.DbgAutoClearLimitTexts = Max(10000, hr.DbgAutoClearLimitTexts)
        pos = pos or SelectedObj or GetCursorPos()
        local pfclass = 0
        if IsKindOf(pos, "Movable") then
            pfclass = pos:GetPfClass()
        end
        pos = terrain.FindPassable(pos)
        print(ValueToStr(ConnectivityPatchInfo(ConnectivityGameToPatch(pos), pfclass)))
    end

    ---
    --- Recalculates the connectivity patch for the given position and pathfinding class.
    ---
    --- @param pos point The position to recalculate the connectivity patch for.
    ---
    function TestConnectivityRecalcPatch(pos)
        pos = pos or SelectedObj or GetCursorPos()
        local grid = 0
        if IsKindOf(pos, "Movable") then
            grid = table.get(pos:GetPfClassData(), "pass_grid") or 0
        end
        pos = terrain.FindPassable(pos)
        ConnectivityRecalcPatch(ConnectivityGameToPatch(pos, grid))
    end

    ---
    --- Performs a performance test for the connectivity system.
    ---
    --- This function tests the performance of the connectivity system by generating a large number of random positions within the play area, and checking the connectivity between the given position and the random positions.
    ---
    --- @param pos point The position to test the connectivity from.
    ---
    function TestConnectivityPerformance(pos)
        pos = terrain.FindPassable(pos or SelectedObj or GetCursorPos())
        local minx, miny, maxx, maxy = GetPlayBox(guim):xyxy()
        local seed = 0
        local count = 100000
        local x, y
        local target = point()
        SuspendThreadDebugHook(1)
        local st = GetPreciseTicks(1000000)
        for i = 1, count do
            x, seed = BraidRandom(seed, minx, maxx - 1)
            y, seed = BraidRandom(seed, miny, maxy - 1)
            if terrain.IsPassable(x, y) then
                target:InplaceSet(x, y)
                ConnectivityClear()
                ConnectivityCheck(pos, target)
            end
        end
        print("Avg Time:", (GetPreciseTicks(1000000) - st) / (1000.0 * count))
        print("Stats:", ConnectivityStats())
        ResumeThreadDebugHook(1)
    end

end -- Platform.asserts