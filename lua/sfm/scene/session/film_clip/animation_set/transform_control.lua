include("control")

util.register_class("sfm.TransformControl",sfm.BaseElement)

sfm.BaseElement.RegisterAttribute(sfm.TransformControl,"valuePosition",Vector())
sfm.BaseElement.RegisterAttribute(sfm.TransformControl,"valueOrientation",Quaternion())
sfm.BaseElement.RegisterProperty(sfm.TransformControl,"positionChannel",sfm.Channel)
sfm.BaseElement.RegisterProperty(sfm.TransformControl,"orientationChannel",sfm.Channel)

function sfm.TransformControl:__init()
  sfm.BaseElement.__init(self,sfm.TransformControl)
end

function sfm.TransformControl:ToPFMControl(pfmControl)
  local sfmChannel = self:GetPositionChannel()
  if(sfmChannel ~= nil) then
    sfmChannel:ToPFMChannel(pfmControl:GetPositionChannel())
  end
  
  sfmChannel = self:GetOrientationChannel()
  if(sfmChannel ~= nil) then
    sfmChannel:ToPFMChannel(pfmControl:GetRotationChannel())
  end
end