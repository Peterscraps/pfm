--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("track")

udm.ELEMENT_TYPE_PFM_TRACK = udm.register_element("PFMTrack")
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"audioClips",udm.Array(udm.ELEMENT_TYPE_PFM_AUDIO_CLIP))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"filmClips",udm.Array(udm.ELEMENT_TYPE_PFM_FILM_CLIP))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"overlayClips",udm.Array(udm.ELEMENT_TYPE_PFM_OVERLAY_CLIP))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"channelClips",udm.Array(udm.ELEMENT_TYPE_PFM_CHANNEL_CLIP))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"muted",udm.Bool(false),{
	getter = "IsMuted"
})
udm.register_element_property(udm.ELEMENT_TYPE_PFM_TRACK,"volume",udm.Float(1.0))
function udm.PFMTrack:AddAudioClip(name)
	local clip = self:CreateChild(udm.ELEMENT_TYPE_PFM_AUDIO_CLIP,name)
	self:GetAudioClipsAttr():PushBack(clip)
	return clip
end
function udm.PFMTrack:AddFilmClip(name)
	local clip = self:CreateChild(udm.ELEMENT_TYPE_PFM_FILM_CLIP,name)
	self:GetFilmClipsAttr():PushBack(clip)
	return clip
end
function udm.PFMTrack:AddOverlayClip(name)
	local clip = self:CreateChild(udm.ELEMENT_TYPE_PFM_OVERLAY_CLIP,name)
	self:GetOverlayClipsAttr():PushBack(clip)
	return clip
end
function udm.PFMTrack:AddChannelClip(name)
	local clip = self:CreateChild(udm.ELEMENT_TYPE_PFM_CHANNEL_CLIP,name)
	self:GetChannelClipsAttr():PushBack(clip)
	return clip
end

function udm.PFMTrack:CalcBonePose(transform,t)
	local posLayer,posChannel,posChannelClip = self:FindBoneChannelLayer(transform,"position")
	local rotLayer,rotChannel,rotChannelClip = self:FindBoneChannelLayer(transform,"rotation")

	-- We need the time relative to the respective channel clip
	local tPos = (posChannelClip ~= nil) and (t -posChannelClip:GetTimeFrame():GetStart()) or t
	local tRot = (rotChannelClip ~= nil) and (t -rotChannelClip:GetTimeFrame():GetStart()) or t

	local pos = (posLayer ~= nil) and posLayer:CalcInterpolatedValue(tPos) or Vector()
	local rot = (rotLayer ~= nil) and rotLayer:CalcInterpolatedValue(tRot) or Quaternion()
	return phys.ScaledTransform(pos,rot,Vector(1,1,1))
end

function udm.PFMTrack:FindBoneChannelLayer(transform,attribute)
	local channel,channelClip = self:FindBoneChannel(transform,attribute)
	local log = (channel ~= nil) and channel:GetLog() or nil
	if(log ~= nil) then return log:GetLayers():Get(1),channel,channelClip end
end

function udm.PFMTrack:SetPlaybackOffset(localOffset,absOffset)
	for _,filmClip in ipairs(self:GetFilmClips():GetTable()) do
		filmClip:SetPlaybackOffset(absOffset)
	end

	for _,channelClip in ipairs(self:GetChannelClips():GetTable()) do
		channelClip:SetPlaybackOffset(localOffset)
	end
end

function udm.PFMTrack:FindFlexControllerChannel(flexWeight)
	for _,channelClip in ipairs(self:GetChannelClips():GetTable()) do
		for _,channel in ipairs(channelClip:GetChannels():GetTable()) do
			local toElement = channel:GetToElement()
			if(toElement ~= nil and toElement:GetType() == udm.ELEMENT_TYPE_PFM_GLOBAL_FLEX_CONTROLLER_OPERATOR) then
				local flexWeightTo = toElement:FindModelFlexWeight()
				if(util.is_same_object(flexWeight,flexWeightTo)) then
					return channel,channelClip
				end
			end
		end
	end
end

function udm.PFMTrack:FindBoneChannel(transform,attribute)
	for _,channelClip in ipairs(self:GetChannelClips():GetTable()) do
		for _,channel in ipairs(channelClip:GetChannels():GetTable()) do
			local toElement = channel:GetToElement()
			if(toElement ~= nil and toElement:GetType() == udm.ELEMENT_TYPE_TRANSFORM) then
				if(util.is_same_object(toElement,transform)) then
					if(attribute == nil or channel:GetToAttribute() == attribute) then
						return channel,channelClip
					end
				end
			end
		end
	end
end