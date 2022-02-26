--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

pfm = pfm or {}

util.register_class("pfm.AnimationManager")
function pfm.AnimationManager.__init()
end

function pfm.AnimationManager:Initialize(track)
end

function pfm.AnimationManager:Reset()
	self.m_filmClip = nil
end

function pfm.AnimationManager:SetFilmClip(filmClip)
	self.m_filmClip = filmClip

	for ent in ents.iterator({ents.IteratorFilterComponent(ents.COMPONENT_PFM_ACTOR)}) do
		self:PlayActorAnimation(ent)
	end
end

local cvPanima = console.get_convar("pfm_experimental_enable_panima_for_flex_and_skeletal_animations")
function pfm.AnimationManager:PlayActorAnimation(ent)
	if(self.m_filmClip == nil or cvPanima:GetBool() == false) then return end
	local actorC = ent:GetComponent(ents.COMPONENT_PFM_ACTOR)
	local actorData = actorC:GetActorData()

	local clip = self.m_filmClip:FindActorAnimationClip(actorData)
	if(clip == nil) then return end
	local animC = ent:AddComponent(ents.COMPONENT_PANIMA)
	local animManager = animC:AddAnimationManager("pfm")
	local player = animManager:GetPlayer()
	player:SetPlaybackRate(0.0)
	local anim = clip:GetPanimaAnimation()
	pfm.log("Playing actor animation '" .. tostring(anim) .. "' for actor '" .. tostring(ent) .. "'...",pfm.LOG_CATEGORY_PFM)
	animC:PlayAnimation(animManager,anim)
end

function pfm.AnimationManager:SetTime(t)
	if(self.m_filmClip == nil) then return end
	for ent in ents.iterator({ents.IteratorFilterComponent(ents.COMPONENT_PFM_ACTOR),ents.IteratorFilterComponent(ents.COMPONENT_PANIMA)}) do
		local animC = ent:GetComponent(ents.COMPONENT_PANIMA)
		local manager = animC:GetAnimationManager("pfm")
		if(manager ~= nil) then
			local player = manager:GetPlayer()
			local lt = t
			if(lt) then
				local pfmActorC = ent:GetComponent(ents.COMPONENT_PFM_ACTOR)
				local animClip = (pfmActorC ~= nil) and self.m_filmClip:FindActorAnimationClip(pfmActorC:GetActorData()) or nil
				if(animClip ~= nil) then
					local start = animClip:GetTimeFrame():GetStart()
					lt = lt -start
				end
			end
			player:SetCurrentTime(lt or player:GetCurrentTime())
		end
	end
end

function pfm.AnimationManager:SetAnimationsDirty()
	for ent in ents.iterator({ents.IteratorFilterComponent(ents.COMPONENT_PFM_ACTOR),ents.IteratorFilterComponent(ents.COMPONENT_PANIMA)}) do
		local animC = ent:GetComponent(ents.COMPONENT_PANIMA)
		local animManager = (animC ~= nil) and animC:GetAnimationManager("pfm") or nil
		if(animManager ~= nil) then
			local player = animManager:GetPlayer()
			player:SetAnimationDirty()
		end
	end
	game.update_animations(0.0)
end

function pfm.AnimationManager:SetAnimationDirty(actor)
	local ent = actor:FindEntity()
	if(util.is_valid(ent) == false) then return end
	local animC = ent:GetComponent(ents.COMPONENT_PANIMA)
	local animManager = (animC ~= nil) and animC:GetAnimationManager("pfm") or nil
	if(animManager == nil) then return end
	local player = animManager:GetPlayer()
	player:SetAnimationDirty()
end

function pfm.AnimationManager:AddChannel(anim,channelClip,channelPath,type)
	pfm.log("Adding animation channel of type '" .. udm.enum_type_to_ascii(type) .. "' with path '" .. channelPath .. "' to animation '" .. tostring(anim) .. "'...",pfm.LOG_CATEGORY_PFM)
	local animChannel = anim:AddChannel(channelPath,type)
	if(animChannel == nil) then
		pfm.log("Failed to add animation channel of type '" .. udm.enum_type_to_ascii(type) .. "' with path '" .. channelPath .. "' to animation '" .. tostring(anim) .. "'...",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return
	end
	local udmChannelTf = channelClip:GetTimeFrame()
	local channelTf = animChannel:GetTimeFrame()
	channelTf.startOffset = udmChannelTf:GetStart()
	channelTf.scale = udmChannelTf:GetScale()
	animChannel:SetTimeFrame(channelTf)
	return animChannel
end

function pfm.AnimationManager:FindAnimationChannel(actor,path,addIfNotExists,type)
	if(self.m_filmClip == nil or self.m_filmClip == nil) then return end
	local animClip,newAnim = self.m_filmClip:FindActorAnimationClip(actor,addIfNotExists)
	if(animClip == nil) then return end

	if(newAnim) then
		local ent = actor:FindEntity()
		if(ent ~= nil) then self:PlayActorAnimation(ent) end
	end
	local anim = animClip:GetPanimaAnimation()
	if(anim == nil) then return end
	local channel = anim:FindChannel(path)
	if(channel == nil and addIfNotExists) then
		channel = animClip:GetChannel(path,type,true)
		animClip:SetPanimaAnimationDirty()

		-- New channel added; Reload animation
		local ent = actor:FindEntity()
		if(util.is_valid(ent)) then self:PlayActorAnimation(ent) end
	end
	return anim,anim:FindChannel(path),animClip
end

function pfm.AnimationManager:SetValueExpression(actor,path,expr)
	local anim,channel = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	if(expr == nil) then
		channel:ClearValueExpression()
		return
	end
	local r = channel:SetValueExpression(expr)
	if(r ~= true) then pfm.log("Unable to apply channel value expression '" .. expr .. "' for channel with path '" .. path .. "': " .. r,pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING) end
end

function pfm.AnimationManager:GetValueExpression(actor,path)
	local anim,channel = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	return channel:GetValueExpression()
end

function pfm.AnimationManager:RemoveChannel(actor,path)
	if(self.m_filmClip == nil or self.m_filmClip == nil) then return end
	local anim,channel = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	anim:RemoveChannel(path)
end

function pfm.AnimationManager:SetChannelValue(actor,path,time,value,channelClip,type)
	if(self.m_filmClip == nil or self.m_filmClip == nil) then
		pfm.log("Unable to apply channel value: No active film clip selected, or film clip has no animations!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return
	end
	local anim,channel,animClip = self:FindAnimationChannel(actor,path,true,type)
	assert(channel ~= nil)
	if(channel == nil) then return end
	channel:AddValue(time,value)
	anim:UpdateDuration()
end
