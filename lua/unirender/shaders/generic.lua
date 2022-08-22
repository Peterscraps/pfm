--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

util.register_class("unirender.GenericShader",unirender.Shader)
function unirender.GenericShader:__init()
	unirender.Shader.__init(self)
end
function unirender.GenericShader:ApplyEyeUv(desc,mat,uv)
	local mesh = self:GetMesh()
	local ent = self:GetEntity()
	if(mesh == nil or util.is_valid(ent) == false or mat:GetShaderName() ~= "eye") then return uv end
	local eyeC = ent:GetComponent(ents.COMPONENT_EYE)
	if(eyeC == nil) then return uv end
	local eyeballIndex = eyeC:FindEyeballIndex(mesh:GetSkinTextureIndex())
	if(eyeballIndex == nil) then return uv end
	local dilationFactor = eyeC:GetIrisDilation(eyeballIndex)
	local eyeball = ent:GetModel():GetEyeball(eyeballIndex)
	if(eyeball == nil or dilationFactor == nil) then return uv end
	local irisProjU,irisProjV = eyeC:GetEyeballProjectionVectors(eyeballIndex)
	if(irisProjU == nil) then return uv end
	local eyeUv = desc:AddNode(unirender.NODE_EYE_UV)
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_PROJ_U_XYZ,Vector(irisProjU.x,irisProjU.y,irisProjU.z))
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_PROJ_U_W,irisProjU.w)
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_PROJ_V_XYZ,Vector(irisProjV.x,irisProjV.y,irisProjV.z))
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_PROJ_V_W,irisProjV.w)
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_DILATION,dilationFactor)
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_MAX_DILATION_FACTOR,eyeball.maxDilationFactor)
	eyeUv:SetProperty(unirender.Node.eye_uv.IN_IRIS_UV_RADIUS,eyeball.irisUvRadius)
	return eyeUv:GetPrimaryOutputSocket()
end
function unirender.GenericShader:AddTextureNode(desc,dbVolumetric,factorName,mapName)
	local mat = self:GetMaterial()
	if(mat == nil) then return end
	local data = mat:GetDataBlock()
	local factor = dbVolumetric:GetVector(factorName,Vector(0,0,0))

	local map = dbVolumetric:GetString(mapName)
	if(map == nil or #map == 0) then return unirender.Socket(factor) end
	local texPath = unirender.get_texture_path(map)
	if(texPath == nil) then return unirender.Socket(factor) end

	local nMap = desc:AddTextureNode(texPath)
	return nMap:GetPrimaryOutputSocket() *unirender.Socket(factor)
end
function unirender.GenericShader:LinkDefaultVolume(desc,outputNode)
	local mat = self:GetMaterial()
	if(mat == nil) then return end
	local data = mat:GetDataBlock()
	local dbVolumetric = mat and mat:GetDataBlock():FindBlock("volumetric")
	if(dbVolumetric ~= nil) then
		local enabled = true
		if(dbVolumetric:HasValue("enabled")) then enabled = dbVolumetric:GetBool("enabled") end
		if(enabled == true) then
			local type = dbVolumetric:GetString("type","homogeneous"):lower()
			local node
			if(type == "clear") then
				node = desc:AddNode(unirender.NODE_VOLUME_CLEAR)
			else
				if(type == "homogeneous") then
					node = desc:AddNode(unirender.NODE_VOLUME_HOMOGENEOUS)

					self:AddTextureNode(desc,dbVolumetric,"scattering_factor","scattering_map"):Link(node,unirender.Node.volume_homogeneous.IN_SCATTERING)
					self:AddTextureNode(desc,dbVolumetric,"asymmetry_factor","asymmetry_map"):Link(node,unirender.Node.volume_homogeneous.IN_ASYMMETRY)
					if(dbVolumetric:HasValue("multiscattering")) then unirender.Socket(dbVolumetric:GetBool("multiscattering",false) and 1 or 0):Link(node,unirender.Node.volume_homogeneous.IN_MULTI_SCATTERING) end
				elseif(type == "heterogeneous") then
					node = desc:AddNode(unirender.NODE_VOLUME_HETEROGENEOUS)

					if(dbVolumetric:HasValue("step_size")) then unirender.Socket(dbVolumetric:GetInt("step_size",0)):Link(node,unirender.Node.volume_heterogeneous.IN_STEP_SIZE) end
					if(dbVolumetric:HasValue("step_max_count")) then unirender.Socket(dbVolumetric:GetInt("step_max_count",0)):Link(node,unirender.Node.volume_heterogeneous.IN_STEP_MAX_COUNT) end
				end
			end
			if(node ~= nil) then
				if(dbVolumetric:HasValue("priority")) then unirender.Socket(dbVolumetric:GetInt("priority",0)):Link(node,unirender.Node.volume_clear.IN_PRIORITY) end
				if(dbVolumetric:HasValue("ior")) then unirender.Socket(dbVolumetric:GetVector("ior",Vector(0.3,0.3,0.3))):Link(node,unirender.Node.volume_clear.IN_IOR) end
				if(dbVolumetric:HasValue("absorption")) then unirender.Socket(dbVolumetric:GetVector("absorption",Vector(0.0,0.0,0.0))):Link(node,unirender.Node.volume_clear.IN_ABSORPTION) end
				self:AddTextureNode(desc,dbVolumetric,"emission_factor","emission_map"):Link(node,unirender.Node.volume_clear.IN_EMISSION)

				node:GetPrimaryOutputSocket():Link(outputNode,unirender.Node.output.IN_VOLUME)
			end
			return node
		end
	end
end

function unirender.apply_image_view_swizzling(desc,texMapNode,texInfo)
	local outRgb = texMapNode:GetPrimaryOutputSocket()
	local outAlpha = texMapNode:GetOutputSocket("alpha")
	if(texInfo == nil) then return outRgb,outAlpha end

	local tex = texInfo:GetTexture()
	local vkTex = (tex ~= nil) and tex:GetVkTexture() or nil
	local imgView = (vkTex ~= nil) and vkTex:GetImageView() or nil
	if(imgView == nil) then return outRgb,outAlpha end
	local swizzleArray = imgView:GetSwizzleArray()
	if(swizzleArray[1] == prosper.COMPONENT_SWIZZLE_R and swizzleArray[2] == prosper.COMPONENT_SWIZZLE_G and swizzleArray[3] == prosper.COMPONENT_SWIZZLE_B and swizzleArray[4] == prosper.COMPONENT_SWIZZLE_A) then return outRgb,outAlpha end
	local components = {
		[prosper.COMPONENT_SWIZZLE_R] = outRgb.r,
		[prosper.COMPONENT_SWIZZLE_G] = outRgb.g,
		[prosper.COMPONENT_SWIZZLE_B] = outRgb.b,
		[prosper.COMPONENT_SWIZZLE_A] = outAlpha
	}
	return desc:CombineRGB(components[swizzleArray[1]],components[swizzleArray[2]],components[swizzleArray[3]]),components[swizzleArray[4]]
end

function unirender.get_swizzle_channels(texInfo)
	local tex = texInfo:GetTexture()
	local vkTex = (tex ~= nil) and tex:GetVkTexture() or nil
	local imgView = (vkTex ~= nil) and vkTex:GetImageView() or nil
	local channels = {prosper.COMPONENT_SWIZZLE_R,prosper.COMPONENT_SWIZZLE_G,prosper.COMPONENT_SWIZZLE_B,prosper.COMPONENT_SWIZZLE_A}
	if(imgView == nil) then return unpack(channels) end
	local swizzleArray = imgView:GetSwizzleArray()
	return unpack(swizzleArray)
end

function unirender.translate_swizzle_channels(texInfo,...)
	if(texInfo == nil) then return ... end
	local tex = texInfo:GetTexture()
	local vkTex = (tex ~= nil) and tex:GetVkTexture() or nil
	local imgView = (vkTex ~= nil) and vkTex:GetImageView() or nil
	if(imgView == nil) then return ... end
	local swizzleArray = imgView:GetSwizzleArray()
	local channels = {...}
	for i,channel in ipairs(channels) do
		channels[i] = swizzleArray[channel]
	end
	return unpack(channels)
end
