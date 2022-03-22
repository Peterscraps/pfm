--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

pfm = pfm or {}

util.register_class("pfm.AnimationManager",util.CallbackHandler)
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
	self.m_time = t
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
		anim = animClip:GetPanimaAnimation()
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
	self:SetAnimationDirty(actor)
	local anim,channel,animClip = self:FindAnimationChannel(actor,path)
	if(animClip ~= nil) then animClip:RemoveChannel(path) end
	if(channel == nil) then return end
	anim:RemoveChannel(path)
end

function pfm.AnimationManager:RemoveChannelValueByIndex(actor,path,idx,updateKey)
	if(updateKey == nil) then updateKey = true end
	if(self.m_filmClip == nil or self.m_filmClip == nil) then
		pfm.log("Unable to apply channel value: No active film clip selected, or film clip has no animations!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return
	end
	local anim,channel,animClip = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	pfm.log("Removing channel value at index " .. idx .. " with channel path '" .. path .. "' of actor '" .. tostring(actor) .. "'...",pfm.LOG_CATEGORY_PFM)

	local t = channel:GetTime(idx)
	channel:RemoveValue(idx)
	anim:UpdateDuration()
	self:SetAnimationDirty(actor)

	-- Remove bookmark
	local editorData = animClip:GetEditorData()
	local editorChannel = editorData:FindChannel(path)
	local keyIndex
	if(updateKey == true and editorChannel ~= nil and t ~= nil) then
		keyIndex = editorChannel:RemoveKey(t)
	end

	local udmChannel = animClip:GetChannel(path,type)
	self:CallCallbacks("OnChannelValueChanged",{
		actor = actor,
		animation = anim,
		channel = channel,
		udmChannel = udmChannel,
		oldIndex = idx,
		keyIndex = keyIndex
	})
end

function pfm.AnimationManager:GetChannelValueByIndex(actor,path,idx)
	if(self.m_filmClip == nil or self.m_filmClip == nil) then return end
	local anim,channel,animClip = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	return channel:GetTime(idx),channel:GetValue(idx)
end

function pfm.AnimationManager:UpdateChannelValueByIndex(actor,path,idx,time,value,updateKey)
	if(updateKey == nil) then updateKey = true end
	if(self.m_filmClip == nil or self.m_filmClip == nil) then
		pfm.log("Unable to apply channel value: No active film clip selected, or film clip has no animations!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return
	end
	local anim,channel,animClip = self:FindAnimationChannel(actor,path)
	if(channel == nil) then return end
	pfm.log("Updating channel value at index " .. idx .. " with value " .. (value and tostring(value) or "n/a") .. " at timestamp " .. (time and tostring(time) or "n/a") .. " with channel path '" .. path .. "' to actor '" .. tostring(actor) .. "'...",pfm.LOG_CATEGORY_PFM)
	if(value ~= nil) then channel:SetValue(idx,value) end

	local oldIdx = idx
	local oldKeyIdx
	local keyIdx
	if(time ~= nil) then
		local oldTime = channel:GetTime(idx)
		channel:SetTime(idx,time)
		-- Since we changed the time value, we may have to re-order
		local function swapValue(idx0,idx1)
			local t0 = channel:GetTime(idx0)
			local v0 = channel:GetValue(idx0)
			local t1 = channel:GetTime(idx1)
			local v1 = channel:GetValue(idx1)
			channel:SetTime(idx0,t1)
			channel:SetValue(idx0,v1)
			channel:SetTime(idx1,t0)
			channel:SetValue(idx1,v0)
		end

		local tNext = channel:GetTime(idx +1)
		while(tNext ~= nil and tNext < time) do
			-- Value needs to be moved up
			swapValue(idx,idx +1)
			idx = idx +1
			tNext = channel:GetTime(idx +1)
		end

		local tPrev = (idx > 0) and channel:GetTime(idx -1) or nil
		while(tPrev ~= nil and tPrev > time) do
			-- Value needs to be moved down
			swapValue(idx,idx -1)
			idx = idx -1
			tPrev = (idx > 0) and channel:GetTime(idx -1) or nil
		end
		--

		anim:UpdateDuration()

		if(updateKey) then
			local editorData = animClip:GetEditorData()
			local editorChannel = editorData:FindChannel(path)
			if(editorChannel ~= nil) then
				oldKeyIdx,keyIdx = editorChannel:SetKeyTime(oldTime,time)
			end
		end
	end
	self:SetAnimationDirty(actor)

	local udmChannel = animClip:GetChannel(path,type)
	self:CallCallbacks("OnChannelValueChanged",{
		actor = actor,
		animation = anim,
		channel = channel,
		udmChannel = udmChannel,
		index = idx,
		oldIndex = oldIdx,
		oldKeyIndex = oldKeyIdx,
		keyIndex = keyIdx
	})
end

function pfm.AnimationManager:SetChannelValue(actor,path,time,value,type,addKey)
	if(addKey == nil) then addKey = true end
	if(self.m_filmClip == nil or self.m_filmClip == nil) then
		pfm.log("Unable to apply channel value: No active film clip selected, or film clip has no animations!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return
	end
	pfm.log("Setting channel value " .. tostring(value) .. " of type " .. udm.type_to_string(type) .. " at timestamp " .. time .. " with channel path '" .. path .. "' to actor '" .. tostring(actor) .. "'...",pfm.LOG_CATEGORY_PFM)
	local anim,channel,animClip = self:FindAnimationChannel(actor,path,true,type)
	assert(channel ~= nil)
	if(channel == nil) then return end
	local idx = channel:AddValue(time,value)
	anim:UpdateDuration()

	local keyIdx
	if(addKey) then
		local editorData = animClip:GetEditorData()
		local editorChannel = editorData:FindChannel(path,true)
		-- TODO: Vec3, etc. -> Split into components!
		local keyData
		keyData,keyIndex = editorChannel:AddKey(time)
		keyData:SetValue(keyIndex,value)
	end

	local udmChannel = animClip:GetChannel(path,type)
	self:CallCallbacks("OnChannelValueChanged",{
		actor = actor,
		animation = anim,
		channel = channel,
		udmChannel = udmChannel,
		index = idx,
		oldIndex = idx,
		keyIndex = keyIndex
	})
end

function pfm.AnimationManager:SetCurveChannelValueCount(actor,path,startIndex,endIndex,numValues)
	if(self.m_filmClip == nil or self.m_filmClip == nil) then
		pfm.log("Unable to apply channel value: No active film clip selected, or film clip has no animations!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		return false
	end

	local anim,channel,animClip = self:FindAnimationChannel(actor,path)
	local editorData = animClip:GetEditorData()
	local editorChannel = editorData:FindChannel(path,true)
	if(channel == nil) then return false end

	local startTime = channel:GetTime(startIndex)
	local endTime = channel:GetTime(endIndex)
	if(startIndex == false or endTime == false) then return false end

	local startVal = channel:GetValue(startIndex)
	local endVal = channel:GetValue(endIndex)

	local numCurValues = endIndex -startIndex -1
	if(numCurValues > numValues) then
		local nRemove = numCurValues -numValues
		channel:RemoveValueRange(startIndex +1,nRemove)
		endIndex = endIndex -nRemove
	elseif(numCurValues < numValues) then
		local nAdd = numValues -numCurValues
		channel:AddValueRange(startIndex +1,nAdd)
		endIndex = endIndex +nAdd
	end

	local dt = endTime -startTime
	local numValuesIncludingEndpoints = numValues +2
	local dtPerValue = dt /(numValuesIncludingEndpoints -1)
	local curTime = startTime +dtPerValue
	local curIndex = startIndex +1
	for i=0,numValues -1 do
		channel:SetTime(curIndex,curTime)
		local f = (i +1) /(numValuesIncludingEndpoints -1)
		channel:SetValue(curIndex,math.lerp(startVal,endVal,f))

		curTime = curTime +dtPerValue
		curIndex = curIndex +1
	end

	local udmChannel = animClip:GetChannel(path,type)
	self:CallCallbacks("OnChannelValueChanged",actor,anim,channel,udmChannel)
	return true,endIndex
end
