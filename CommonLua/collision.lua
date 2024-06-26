--- Initializes the collision module's variable table.
--
-- This function sets up the `collision` module's variable table, prefixing all variables with `collision.`.
--
-- @function SetupVarTable
-- @param module the module table to set up
-- @param prefix the prefix to use for the variables
SetupVarTable(collision, "collision.")

_AsyncCollideCallbacks = {}

--- Defines a class `TerrainCollision` that inherits from the `Object` class. This class has the `cofComponentCollider` flag set, indicating that it is a collider component.
DefineClass.TerrainCollision = {__parents={"Object"}, flags={cofComponentCollider=true}}
