--- Map objects query functions ----

-- see Docs/LuaMapEnumeration.md.html for a detailed description of the query parameters

--- Returns all objects in the map that match the criteria specified in the query list.
-- @cstyle objlist MapGet(list query).
-- @param  query list containing all criteria that an object has to meet to be returned by the function; see above.
-- @return objlist; all objects that match the query in the map. Returns nothing if no objects matched.
function MapGet(list)
end

--- Returns first object in the map that match the criteria specified in the query list.
-- @cstyle objlist MapGet(list query).
-- @param  query list containing all criteria that an object has to meet to be returned by the function; see above.
-- @return obj; one object that match the query in the map.
function MapGetFirst(list)
end

--- Returns the count of all objects in the map that match the criteria specified in the query list.
-- @cstyle int MapCount(query).
-- @param  query - list containing all criteria that an object has to meet to be returned by the function; see above.
-- @return objcount; 
function MapCount(list)
end

---Calls specified function on every object on the map that match the criteria specified in the query list.
-- @cstyle int MapForEach(query).
-- @param  query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return objcount; count of objects which has been filtered out for the function.
function MapForEach(list)
end

---From all of the objects that match the criteria specified in the query list finds the one with least evaluation (returned by the specified function parameter).
-- @cstyle object MapFindMin(query).
-- @param  query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return obj, obj_eval; return object match and number of evaluations.
function MapFindMin(list)
end

---From all of the objects that match the criteria specified in the query list finds the closest to the object specified as a first param in the list.
-- @cstyle objlist MapFindNearest(obj, query).
-- @param  obj - reference object for the search; query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return obj, obj_eval; nearest object, number of evaluations
-- note: function specified takes at least two params by default: filtered object and reference object specified in first arguement
function MapFindNearest(obj, list)
end

---From all of the objects that match the criteria specified in the query list finds the one that takes shortest path to reach from the specified object/point.
-- @cstyle object MapFindShortestPath(obj, query).
-- @param  obj - reference object for the search; query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return obj; return object match or, if no match, all objects matched criteria. ?
function MapFindShortestPath(obj, list)
end

--- Returns all objects in the filter_list that match the criteria specified in the query list.
-- The syntax sugar member of objlist objlist:MapFilter(list) can also be used.
-- @cstyle objlist MapFilter(objlist list, query).
-- @param query table describing all criteria that an object has to meet to be returned by the function; see above.
-- @return objlist; all objects that match the query in the list.
function MapFilter(obj_list, list)
end

---Deletes all of the objects that match the criteria specified in the query list.
-- @cstyle int MapDelete(query).
-- @param  query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return objcount; count of objects which has been filtered out for deletion.
function MapDelete(...)
end

---Sets/Clears specified flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int Map{Set/Clear}{Enum/Game/Hierarchy}Flags(action_data, query).
-- @param  action_data - enum flag to set/clear; query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return objcount; count of objects which has been filtered out.
function MapSetEnumFlags(action_data, list)
end

---Sets/Clears specified flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapClearEnumFlags(action_data, query).
-- @param  action_data - enum flag to clear; query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return objcount; count of objects which has been filtered out.
function MapClearEnumFlags(action_data, list)
end

---Sets specified flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapSetGameFlags(action_data, query).
-- @param  action_data - game flag to set; query - list containing all criteria that an object has to meet to be processed by the specified function. 
-- @return objcount; count of objects which has been filtered out.
function MapSetGameFlags(action_data, list)
end

---Clears specified game flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapClearGameFlags(action_data, query).
-- @param  action_data - game flag to clear
-- @param  list - list containing all criteria that an object has to meet to be processed by the specified function
-- @return objcount; count of objects which has been filtered out
function MapClearGameFlags(action_data, list)
end

---Sets specified hierarchy enum flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapSetHierarchyEnumFlags(action_data, query).
-- @param  action_data - hierarchy enum flag to set
-- @param  list - list containing all criteria that an object has to meet to be processed by the specified function
-- @return objcount; count of objects which has been filtered out
function MapSetHierarchyEnumFlags(action_data, list)
end

---Clears specified hierarchy enum flag for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapClearHierarchyEnumFlags(action_data, query).
-- @param  action_data - hierarchy enum flag to clear
-- @param  list - list containing all criteria that an object has to meet to be processed by the specified function
-- @return objcount; count of objects which has been filtered out
function MapClearHierarchyEnumFlags(action_data, list)
end

---Sets/Clears specified collection index for all of the objects that match the criteria specified in the query list.
-- @cstyle int MapSetCollectionIndex(action_data, list).
-- @param  action_data - collection index to set
-- @param  list - list containing all criteria that an object has to meet to be processed by the specified function
-- @return objcount; count of objects which has been filtered out
function MapSetCollectionIndex(action_data, list)
end
