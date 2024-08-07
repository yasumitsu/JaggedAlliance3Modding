DefineClass.CameraFacingSign = {
	__parents = {"Object", "CameraFacingObject"},
	attach_spot = "Origin",
	attach_offset = point30,
}

--- Sets the camera facing property of the CameraFacingSign object to true.
-- This ensures that the object will always face the camera, regardless of its orientation.
function CameraFacingSign:Init()
	self:SetCameraFacing(true)
end

DefineClass.CameraFacingSignUnit = {
	__parents = { "CameraFacingSign" },
	attach_spot = "Headstatic",
	attach_offset = point(0, 0, guic*75),
}
