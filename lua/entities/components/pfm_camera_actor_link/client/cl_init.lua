--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

local Component = util.register_class("ents.PFMCameraActorLink",BaseEntityComponent)

function Component:Initialize()
	BaseEntityComponent.Initialize(self)

	self.m_listeners = {}
	self:BindEvent(ents.TransformComponent.EVENT_ON_POSE_CHANGED,"OnPoseChanged")
	local camC = self:GetEntityComponent(ents.COMPONENT_CAMERA)
	if(camC ~= nil) then
		table.insert(self.m_listeners,camC:GetFOVProperty():AddCallback(function() self:OnPoseChanged() end))
	end
end
function Component:OnRemove()
	util.remove(self.m_listeners)
end
function Component:SetTargetActor(actor) self.m_targetActor = actor end
function Component:OnPoseChanged()
	if(util.is_valid(self.m_targetActor) == false) then return end
	self.m_targetActor:SetPose(self:GetEntity():GetPose())
	local camC = self:GetEntity():GetComponent(ents.COMPONENT_CAMERA)
	if(camC == nil) then return end
	local lightC = self.m_targetActor:GetComponent(ents.COMPONENT_LIGHT_SPOT)
	if(lightC ~= nil) then
		lightC:SetOuterConeAngle(camC:GetFOV())
	end
end
ents.COMPONENT_PFM_CAMERA_ACTOR_LINK = ents.register_component("pfm_camera_actor_link",Component)
