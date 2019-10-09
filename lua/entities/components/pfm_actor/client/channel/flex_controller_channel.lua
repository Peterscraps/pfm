--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

util.register_class("ents.PFMActorComponent.FlexControllerChannel",ents.PFMActorComponent.Channel)
function ents.PFMActorComponent.FlexControllerChannel:__init()
	ents.PFMActorComponent.Channel.__init(self)
end
function ents.PFMActorComponent.FlexControllerChannel:GetInterpolatedValue(value0,value1,interpAm)
	return math.lerp(value0,value1,interpAm)
end
function ents.PFMActorComponent.FlexControllerChannel:TranslateFlexControllerValue(fc,val)
	return fc.min +val *(fc.max -fc.min)
end
function ents.PFMActorComponent.FlexControllerChannel:ApplyValue(ent,controllerId,value)
	local flexC = ent:GetComponent(ents.COMPONENT_FLEX)
	local mdl = ent:GetModel()
	local fc = (mdl ~= nil) and mdl:GetFlexController(controllerId) or nil -- TODO: Cache this
	if(flexC == nil or fc == nil) then return false end
	flexC:SetFlexController(controllerId,self:TranslateFlexControllerValue(fc,value))
	return true
end
