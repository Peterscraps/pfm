--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

local Component = util.register_class("ents.PFMCursorTarget",BaseEntityComponent)

function Component:Initialize()
	BaseEntityComponent.Initialize(self)

	self:SetTickPolicy(ents.TICK_POLICY_ALWAYS)
end
function Component:GetLastRayInfo() return self.m_lastRayInfo end
local function is_same_entity(ent0,ent1)
	if(util.is_valid(ent0) == false) then
		if(util.is_valid(ent1) == false) then return true end
		return false
	elseif(util.is_valid(ent1) == false) then return false end
	return ent0 == ent1
end
function Component:OnTick(dt)
	local startPos,dir,vpData = ents.ClickComponent.get_ray_data()
	if(startPos == nil) then self:SetNextTick(time.cur_time() +0.2) return end
	local filter
	if(util.is_valid(vpData.viewport)) then
		local scene = vpData.viewport:GetScene()
		if(util.is_valid(scene)) then
			filter = function(ent)
				return ent:IsInScene(scene)
			end
		end
	end
	local actor,hitPos,pos,hitData = pfm.raycast(startPos,dir,maxDist,filter)
	local prevRayInfo = self.m_lastRayInfo
	self.m_lastRayInfo = {
		actor = actor,
		hitPos = hitPos,
		startPos = pos,
		hitData = hitData,
		vpData = vpData
	}
	self:SetNextTick(time.cur_time() +0.05)

	if(prevRayInfo == nil or is_same_entity(actor,prevRayInfo.actor) == false) then
		self:InvokeEventCallbacks(Component.EVENT_ON_TARGET_ACTOR_CHANGED,{self.m_lastRayInfo,prevActor})
	end
	if(prevRayInfo == nil or is_same_entity(actor,prevRayInfo.actor) == false or hitPos ~= prevRayInfo.hitPos or (hitData == nil and prevRayInfo.hitData ~= nil) or 
		(hitData ~= nil and prevRayInfo.hitData == nil) or (hitData ~= nil and prevRayInfo.hitData ~= nil and (prevRayInfo.hitData.primitiveIndex ~= hitData.primitiveIndex or prevRayInfo.hitData.mesh ~= hitData.mesh))) then
		self:InvokeEventCallbacks(Component.EVENT_ON_TARGET_CHANGED,{self.m_lastRayInfo})
	end
end
ents.COMPONENT_PFM_CURSOR_TARGET = ents.register_component("pfm_cursor_target",Component)
Component.EVENT_ON_TARGET_CHANGED = ents.register_component_event(ents.COMPONENT_PFM_CURSOR_TARGET,"on_target_changed")
Component.EVENT_ON_TARGET_ACTOR_CHANGED = ents.register_component_event(ents.COMPONENT_PFM_CURSOR_TARGET,"on_target_actor_changed")
