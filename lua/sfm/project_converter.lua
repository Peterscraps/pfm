--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/sfm.lua")
include("/pfm/pfm.lua")
include("/sfm/project_converter/math_expression.lua")

pfm.register_log_category("sfm_converter")

local function log_sfm_project_debug_info(project)
	local numSessions = 0
	local numClips = 0
	local numTracks = 0
	local numFilmClips = 0
	local numAudioClips = 0
	local numAnimationSets = 0
	for _,session in ipairs(project:GetSessions()) do
		numSessions = numSessions +1
		for _,clipSet in ipairs({session:GetClipBin(),session:GetMiscBin()}) do
			for _,clip in ipairs(clipSet) do
				numClips = numClips +1
				local subClipTrackGroup = clip:GetSubClipTrackGroup()
				for _,track in ipairs(subClipTrackGroup:GetTracks()) do
					numTracks = numTracks +1
					for _,filmClip in ipairs(track:GetFilmClips()) do
						numFilmClips = numFilmClips +1
						-- numAnimationSets = numAnimationSets +#filmClip:GetAnimationSets() -- TODO: Obsolete
					end
					numAudioClips = numAudioClips +#track:GetSoundClips()
				end
			end
		end
	end
	pfm.log("---------------------------------------",pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("SFM project information:",pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of sessions: " .. numSessions,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of clips: " .. numClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of tracks: " .. numTracks,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of film clips: " .. numFilmClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of sound clips: " .. numAudioClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of animation sets: " .. numAnimationSets,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("---------------------------------------",pfm.LOG_CATEGORY_PFM_CONVERTER)
end

local function log_pfm_project_debug_info(project)
	local numTracks = 0
	local numFilmClips = 0
	local numAudioClips = 0
	local numChannelClips = 0
	local numActors = 0
	local function iterate_film_clip(filmClip)
		numFilmClips = numFilmClips +1
		numActors = numActors +#filmClip:GetActorList()
		for _,trackGroup in ipairs(filmClip:GetTrackGroups()) do
			for _,track in ipairs(trackGroup:GetTracks()) do
				for _,filmClipOther in ipairs(track:GetFilmClips()) do
					iterate_film_clip(filmClipOther)
				end
				numAudioClips = numAudioClips +#track:GetAudioClips()
				numChannelClips = numChannelClips +#track:GetAnimationClips()
			end
		end
	end
	for _,session in ipairs({project:GetSession()}) do
		for _,clip in ipairs(session:GetClips()) do
			iterate_film_clip(clip)
		end
	end
	pfm.log("---------------------------------------",pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("PFM project information:",pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of film clips: " .. numFilmClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of audio clips: " .. numAudioClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of channel clips: " .. numChannelClips,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("Number of actors: " .. numActors,pfm.LOG_CATEGORY_PFM_CONVERTER)
	pfm.log("---------------------------------------",pfm.LOG_CATEGORY_PFM_CONVERTER)
end

function sfm.is_udm_element_entity_component(el)
	local type = el:GetType()
	-- We only have to check the component types that have a corresponding type in SFM
	return (type == fudm.ELEMENT_TYPE_PFM_MODEL or type == fudm.ELEMENT_TYPE_PFM_CAMERA or type == fudm.ELEMENT_TYPE_PFM_SPOT_LIGHT or type == fudm.ELEMENT_TYPE_PFM_PARTICLE_SYSTEM)
end

local sfm_attr_to_pragma_table = {
	[fudm.ELEMENT_TYPE_PFM_CAMERA] = {
		["fieldofview"] = "fov"
	}
}

util.register_class("sfm.ProjectConverter")
sfm.ProjectConverter.convert_project = function(projectFilePath)
	debug.start_profiling_task("pfm_import_sfm_project")
	local sfmProject = sfm.import_scene(projectFilePath)
	if(sfmProject == nil) then
		debug.stop_profiling_task()
		return false
	end
	log_sfm_project_debug_info(sfmProject)

	local converter = sfm.ProjectConverter(sfmProject)
	local pfmProject = converter:GetPFMProject()
	log_pfm_project_debug_info(pfmProject)

	-- Clear the SFM session data from memory immediately
	converter = nil
	collectgarbage()

	debug.stop_profiling_task()
	return pfmProject
end
sfm.assign_generic_attribute = function(name,attr,pfmObj)
	local type = attr:GetType()
	local v = attr:GetValue()
	if(type == dmx.Attribute.TYPE_INT) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_INT,v))
	elseif(type == dmx.Attribute.TYPE_FLOAT) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_FLOAT,v))
	elseif(type == dmx.Attribute.TYPE_BOOL) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_BOOL,v))
	elseif(type == dmx.Attribute.TYPE_STRING) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_STRING,v))
	elseif(type == dmx.Attribute.TYPE_COLOR) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_COLOR,v))
	elseif(type == dmx.Attribute.TYPE_VECTOR3) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_VECTOR3,v))
	elseif(type == dmx.Attribute.TYPE_ANGLE) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_ANGLE,v))
	elseif(type == dmx.Attribute.TYPE_QUATERNION) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_QUATERNION,v))
	elseif(type == dmx.Attribute.TYPE_UINT64) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_INT,v))
	elseif(type == dmx.Attribute.TYPE_UINT8) then pfmObj:SetProperty(name,fudm.create_attribute(fudm.ATTRIBUTE_TYPE_INT,v))
	else
		pfm.log("Unsupported attribute type '" .. dmx.type_to_string(type) .. "'!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
	end
end
function sfm.ProjectConverter:__init(sfmProject)
	self.m_sfmProject = sfmProject -- Input project
	self.m_pfmProject = pfm.create_project() -- Output project
	self.m_sfmElementToPfmElement = {} -- Cache of converted elements
	self.m_sfmObjectToPfmActor = {}
	self.m_ptConversions = {}

	for _,session in ipairs(sfmProject:GetSessions()) do
		self:ConvertSession(session)
	end
	collectgarbage()
	self:ApplyPostProcessing()
	pfm.log("Conversion of SFM project to PFM project has been completed!",pfm.LOG_CATEGORY_PFM_CONVERTER)
end
function sfm.ProjectConverter:GetSFMProject() return self.m_sfmProject end
function sfm.ProjectConverter:GetPFMProject() return self.m_pfmProject end
function sfm.ProjectConverter:AddParticleSystemDefinitionForConversion(pfmParticle,sfmSystemDef)
	table.insert(self.m_ptConversions,{pfmParticle,sfmSystemDef})
end
function sfm.ProjectConverter:GenerateEmbeddedParticleSystemFile()
	if(#self.m_ptConversions == 0) then return end
	local project = self:GetPFMProject()
	local projectName = project:GetName()
	local ptPrefix = projectName .. "_"
	local particleSystems = {}
	local function extract_children(particleSystems,t)
		local children = {}
		if(t.children ~= nil) then
			for name,child in pairs(t.children) do
				local delay = child.delay
				local childData = child.childData
				local newName = ptPrefix .. name
				table.insert(children,{
					delay = delay,
					childName = newName
				})
				extract_children(particleSystems,childData)
				particleSystems[newName] = childData
			end
		else
			-- No children?
		end
		t.children = children
	end
	for _,ptData in ipairs(self.m_ptConversions) do
		local pfmParticle = ptData[1]
		local sfmSystemDef = ptData[2]
		local name = sfmSystemDef:GetName()
		local dmxEl = sfmSystemDef:GetDMXElement()
		local keyValues = sfm.convert_dmx_particle_system(dmxEl)

		extract_children(particleSystems,keyValues)
		particleSystems[ptPrefix .. name] = keyValues

		pfmParticle:SetParticleSystemName(ptPrefix .. name)
	end

	-- Convert particle systems to Pragma
	for name,ptDef in pairs(particleSystems) do
		sfm.convert_particle_system(ptDef)
	end

	-- Save in Pragma's format
	local fileName = util.Path("sessions/" .. projectName .. "_instanced")
	-- console.print_table(particleSystems)
	local success = game.save_particle_system(fileName:GetString(),particleSystems)
	if(success == false) then
		pfm.log("Unable to save particle system file '" .. fileName:GetString() .. "'!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
	end
end

local g_sfmToPfmConversion = {}
sfm.register_element_type_conversion = function(sfmType,conversionFunction)
	if(sfmType == nil) then
		error("Invalid SFM type '" .. util.get_type_name(sfmType) .. "' specified for conversion to PFM!")
	end
	g_sfmToPfmConversion[util.get_type_name(sfmType)] = conversionFunction
end

function sfm.ProjectConverter:ConvertElementToPfm(sfmElement,pfmElement)
	local data = g_sfmToPfmConversion[util.get_type_name(sfmElement)]
	if(data == nil) then
		pfm.error("No PFM conversion function exists for SFM element of type '" .. util.get_type_name(sfmElement) .. "'!")
	end
	return data(self,sfmElement,pfmElement)
end

sfm.register_element_type_conversion(sfm.RenderSettings,function(converter,sfmRenderSettings,pfmRenderSettings)
	pfmRenderSettings:SetFrameRate(sfmRenderSettings:GetFrameRate())
end)

sfm.ProjectConverter.TRANSFORM_TYPE_NONE = -1
sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC = 0
sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL = 1
sfm.ProjectConverter.TRANSFORM_TYPE_BONE = 2
sfm.ProjectConverter.TRANSFORM_TYPE_ALT = 3
local function convert_transform(sfmTransform,pfmTransform,type)
	type = type or sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC
	if(type == sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC) then
		pfmTransform:SetOrigin(sfm.convert_source_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL) then
		pfmTransform:SetOrigin(sfm.convert_source_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_global_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_BONE) then
		pfmTransform:SetOrigin(sfm.convert_source_anim_set_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_anim_set_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_ALT) then
		pfmTransform:SetOrigin(sfm.convert_source_transform_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_transform_rotation_to_pragma2(sfmTransform:GetOrientation()))
	else
		pfmTransform:SetOrigin(sfmTransform:GetPosition())
		pfmTransform:SetRotation(sfmTransform:GetOrientation())
	end

	local scale = sfmTransform:GetScale()
	if(util.get_type_name(pfmTransform) == "ScaledTransform") then pfmTransform:SetScale(Vector(scale,scale,scale)) end
end

local function apply_base_actor_properties(converter,sfmActor,pfmActor,transformType)
	local ct = pfmActor:AddComponentType("pfm_actor")
	ct:SetMemberValue("visible",udm.TYPE_BOOLEAN,sfmActor:IsVisible())

	pfmActor:SetName(sfmActor:GetName())
	local pfmTransform = math.ScaledTransform()
	convert_transform(sfmActor:GetTransform(),pfmTransform,transformType)

	ct:SetMemberValue("position",udm.TYPE_VECTOR3,pfmTransform:GetOrigin())
	ct:SetMemberValue("rotation",udm.TYPE_QUATERNION,pfmTransform:GetRotation())
	ct:SetMemberValue("scale",udm.TYPE_VECTOR3,pfmTransform:GetScale())

	converter.m_sfmObjectToPfmActor[sfmActor] = tostring(pfmActor:GetUniqueId())
end

sfm.register_element_type_conversion(sfm.ProjectedLight,function(converter,sfmLight,pfmActor)
	apply_base_actor_properties(converter,sfmLight,pfmActor,sfm.ProjectConverter.TRANSFORM_TYPE_ALT)

	local cPls = pfmActor:AddComponentType("pfm_light_spot")

	local cC = pfmActor:AddComponentType("color")
	cC:SetMemberValue("color",udm.TYPE_VECTOR3,sfmLight:GetColor():ToVector())
	
	local cL = pfmActor:AddComponentType("light")
	cL:SetMemberValue("intensity",udm.TYPE_FLOAT,sfmLight:GetIntensity())
	cL:SetMemberValue("intensityType",udm.TYPE_STRING,"Candela")
	cL:SetMemberValue("castShadows",udm.TYPE_BOOLEAN,sfmLight:ShouldCastShadows())

	local cLs = pfmActor:AddComponentType("light_spot")
	local fov = math.max(sfmLight:GetHorizontalFOV(),sfmLight:GetVerticalFOV())
	fov = fov *0.5
	cLs:SetMemberValue("innerConeAngle",udm.TYPE_FLOAT,fov *0.7)
	cLs:SetMemberValue("outerConeAngle",udm.TYPE_FLOAT,fov)

	local cR = pfmActor:AddComponentType("radius")
	cR:SetMemberValue("radius",udm.TYPE_FLOAT,sfmLight:GetMaxDistance())

	-- pfmLight:SetFalloffExponent(1.0)
	-- pfmLight:SetVolumetric(sfmLight:IsVolumetric())
	-- pfmLight:SetVolumetricIntensity(sfmLight:GetVolumetricIntensity() *0.05)
end)

-- Calculates local bodygroup indices from a global bodygroup index
local function global_bodygroup_to_local_indices(bgIdx,mdl)
	mdl = game.load_model(mdl)
	if(mdl == nil) then return {} end
	local bodyGroups = mdl:GetBodyGroups()

	-- Calculate total number of bodygroup combinations
	local numCombinations = 1
	for _,bg in ipairs(bodyGroups) do
		numCombinations = numCombinations *#bg.meshGroups
	end

	local localBgIndices = {}
	for i=#bodyGroups,1,-1 do
		local bg = bodyGroups[i]
		numCombinations = numCombinations /#bg.meshGroups
		local localBgIdx = math.floor(bgIdx /numCombinations)
		bgIdx = bgIdx %numCombinations

		-- TODO: This is in reverse order because that's how it's done in the SFM,
		-- but there's really no reason to. Instead the global index should be inversed
		-- in the SFM->PFM conversion script!
		table.insert(localBgIndices,1,localBgIdx)
	end
	return localBgIndices
end

sfm.register_element_type_conversion(sfm.GameModel,function(converter,sfmGm,pfmActor)
	apply_base_actor_properties(converter,sfmGm,pfmActor,sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL)

	pfmActor:AddComponentType("pfm_model")
	local cM = pfmActor:AddComponentType("model")
	local mdlName = asset.normalize_asset_name(sfmGm:GetPragmaModelPath(),asset.TYPE_MODEL)
	cM:SetMemberValue("model",udm.TYPE_STRING,mdlName)
	cM:SetMemberValue("skin",udm.TYPE_UINT32,sfmGm:GetSkin())

	local mdl = game.load_model(mdlName)
	if(mdl ~= nil) then
		local bodyGroups = global_bodygroup_to_local_indices(sfmGm:GetBody(),mdlName)
		local namedBodyGroups = {}
		for bgId,val in pairs(bodyGroups) do
			local bg = mdl:GetBodyGroup(bgId -1)
			if(bg ~= nil) then
				namedBodyGroups[bg.name] = val
			else
				pfm.log("Bodygroup " .. bgId .. " of model '" .. mdlName .. "' refers to unknown bodygroup! Ignoring...",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
			end
		end
		pfmActor:SetBodyGroups(namedBodyGroups)
	else
		pfm.log("Unable to load model '" .. mdlName .. "'! Bodygroups will not be correct!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
	end
	-- TODO: flexWeights
end)

sfm.register_element_type_conversion(sfm.Camera,function(converter,sfmC,pfmActor)
	apply_base_actor_properties(converter,sfmC,pfmActor,sfm.ProjectConverter.TRANSFORM_TYPE_ALT)

	pfmActor:AddComponentType("pfm_camera")
	local cC = pfmActor:AddComponentType("camera")
	cC:SetMemberValue("fov",udm.TYPE_FLOAT,sfm.convert_source_fov_to_pragma(sfmC:GetFieldOfView()))
	cC:SetMemberValue("nearz",udm.TYPE_FLOAT,sfm.source_units_to_pragma_units(sfmC:GetZNear()))
	cC:SetMemberValue("farz",udm.TYPE_FLOAT,sfm.source_units_to_pragma_units(sfmC:GetZFar()))
	cC:SetMemberValue("aspectRatio",udm.TYPE_FLOAT,sfm.ASPECT_RATIO)
	cC:SetMemberValue("focalDistance",udm.TYPE_FLOAT,sfm.source_units_to_pragma_units(sfmC:GetFocalDistance()))

--[[
	local aperture = sfmC:GetAperture()
	if(aperture > 0.0) then
		pfmCamera:SetDepthOfFieldEnabled(true)
		pfmCamera:SetFStop(sfm.convert_source_aperture_to_fstop(aperture))
	end
	pfmCamera:SetSensorSize(36.0)
	pfmCamera:SetApertureBladeCount(3)
]]
end)

sfm.register_element_type_conversion(sfm.GameParticleSystem,function(converter,sfmPs,pfmActor)
	apply_base_actor_properties(converter,sfmPs,pfmActor,sfm.ProjectConverter.TRANSFORM_TYPE_ALT)

	pfmActor:AddComponentType("pfm_particle_system")
--[[
	pfmParticle:SetTimeScale(sfmParticle:GetSimulationTimeScale())
	pfmParticle:SetSimulating(sfmParticle:IsSimulating())
	pfmParticle:SetEmitting(sfmParticle:IsEmitting())
	local ptSystemName = sfmParticle:GetParticleSystemType()
	pfmParticle:SetParticleSystemName(ptSystemName)
	if(#ptSystemName == 0) then
		local ptSystemDef = sfmParticle:GetParticleSystemDefinition()
		local dmxEl = ptSystemDef:GetDMXElement()
		if(dmxEl ~= nil) then
			converter:AddParticleSystemDefinitionForConversion(pfmParticle,ptSystemDef)
		end
	end
	-- pfmParticle:SetDefinition(converter:ConvertNewElement())
	for _,cp in ipairs(sfmParticle:GetControlPoints()) do
		local pfmCp = converter:ConvertNewElement(cp)
		pfmParticle:GetControlPointsAttr():PushBack(pfmCp)
	end
]]
end)

sfm.register_element_type_conversion(sfm.Dag,function(converter,sfmDag,pfmGroup)
	-- TODO: Transform

	for _,child in ipairs(sfmDag:GetChildren()) do
		if(child:GetType() == "DmeProjectedLight" or child:GetType() == "DmeGameModel" or child:GetType() == "DmeCamera" or child:GetType() == "DmeGameParticleSystem") then
			local pfmActor = pfmGroup:AddActor()
			converter:ConvertElementToPfm(child,pfmActor)
		elseif(child:GetType() == "DmeDag") then
			local childGroup = pfmGroup:AddGroup()

			local pfmTransform = childGroup:GetTransform()
			convert_transform(child:GetTransform(),pfmTransform,sfm.ProjectConverter.TRANSFORM_TYPE_ALT)

			childGroup:SetName(child:GetName())
			childGroup:SetTransform(pfmTransform)
			childGroup:SetVisible(child:IsVisible())

			converter:ConvertElementToPfm(child,childGroup)
		end
	end
end)


sfm.register_element_type_conversion(sfm.FilmClip,function(converter,sfmClip,pfmClip)
	converter:ConvertElementToPfm(sfmClip:GetTimeFrame(),pfmClip:GetTimeFrame())
	pfmClip:SetMapName(file.remove_file_extension(sfmClip:GetMapname(),{"bsp"}))
	pfmClip:SetFadeIn(sfmClip:GetFadeIn())
	pfmClip:SetFadeOut(sfmClip:GetFadeOut())
	pfmClip:SetName(sfmClip:GetName())

	-- local animSets = sfmClip:GetAnimationSets()

	-- Bookmark sets
	for _,sfmBs in ipairs(sfmClip:GetBookmarkSets()) do
		local pfmBs = pfmClip:AddBookmarkSet()
		converter:ConvertElementToPfm(sfmBs,pfmBs)
	end
	pfmClip:SetActiveBookmarkSet(sfmClip:GetActiveBookmarkSet())
	--

	-- Scene
	converter:ConvertElementToPfm(sfmClip:GetScene(),pfmClip:GetScene())
	--

	-- Track groups
	for _,sfmTg in ipairs(sfmClip:GetTrackGroups()) do
		local pfmTg = pfmClip:AddTrackGroup()
		converter:ConvertElementToPfm(sfmTg,pfmTg)
	end
	-- TODO: subClipTrackGroup
	--

	-- Animation sets
	--

	local sfmCam = sfmClip:GetCamera()
	if(sfmCam ~= nil) then
		local pfmCam = converter.m_sfmObjectToPfmActor[sfmCam]
		if(pfmCam ~= nil) then pfmClip:SetCamera(pfmCam) end
	end
end)
sfm.register_element_type_conversion(sfm.TimeFrame,function(converter,sfmTimeFrame,pfmTimeFrame)
	pfmTimeFrame:SetStart(sfmTimeFrame:GetStart())
	pfmTimeFrame:SetDuration(sfmTimeFrame:GetDuration())
	pfmTimeFrame:SetOffset(sfmTimeFrame:GetOffset())
	pfmTimeFrame:SetScale(sfmTimeFrame:GetScale())
end)
sfm.register_element_type_conversion(sfm.Bookmark,function(converter,sfmB,pfmB)
	pfmB:SetNote(sfmB:GetNote())
	pfmB:GetTimeRange():SetTime(sfmB:GetTime())
	pfmB:GetTimeRange():SetDuration(sfmB:GetDuration())
end)
sfm.register_element_type_conversion(sfm.BookmarkSet,function(converter,sfmBs,pfmBs)
	for _,sfmB in ipairs(sfmBs:GetBookmarks()) do
		local pfmB = pfmBs:AddBookmark()
		converter:ConvertElementToPfm(sfmB,pfmB)
	end
end)
sfm.register_element_type_conversion(sfm.TrackGroup,function(converter,sfmTg,pfmTg)
	pfmTg:SetName(sfmTg:GetName())
	pfmTg:SetVisible(sfmTg:IsVisible())
	pfmTg:SetMuted(sfmTg:IsMuted())
	for _,sfmT in ipairs(sfmTg:GetTracks()) do
		local pfmT = pfmTg:AddTrack()
		converter:ConvertElementToPfm(sfmT,pfmT)
	end
end)
sfm.register_element_type_conversion(sfm.Track,function(converter,sfmT,pfmT)
	pfmT:SetVolume(sfmT:GetVolume())
	pfmT:SetMuted(sfmT:IsMuted())
	pfmT:SetName(sfmT:GetName())

	for _,sfmCc in ipairs(sfmT:GetChannelClips()) do
		local pfmAc = pfmT:AddAnimationClip()
		converter:ConvertElementToPfm(sfmCc,pfmAc)
	end
	for _,sfmSc in ipairs(sfmT:GetSoundClips()) do
		local pfmAc = pfmT:AddAudioClip()
		converter:ConvertElementToPfm(sfmSc,pfmAc)
	end
	for _,sfmFc in ipairs(sfmT:GetFilmClips()) do
		local pfmFc = pfmT:AddFilmClip()
		converter:ConvertElementToPfm(sfmFc,pfmFc)
	end
	for _,sfmOc in ipairs(sfmT:GetOverlayClips()) do
		local pfmOc = pfmT:AddOverlayClip()
		converter:ConvertElementToPfm(sfmOc,pfmOc)
	end
end)
sfm.register_element_type_conversion(sfm.SoundClip,function(converter,sfmSc,pfmSc)
	converter:ConvertElementToPfm(sfmSc:GetTimeFrame(),pfmSc:GetTimeFrame())
	converter:ConvertElementToPfm(sfmSc:GetSound(),pfmSc:GetSound())
end)
sfm.register_element_type_conversion(sfm.Sound,function(converter,sfmS,pfmS)
	pfmS:SetSoundName(sfmS:GetSoundName())
	pfmS:SetVolume(sfmS:GetVolume())
	pfmS:SetPitch(sfmS:GetPitch())
end)
sfm.register_element_type_conversion(sfm.MaterialOverlayFXClip,function(converter,sfmOc,pfmOc)
	converter:ConvertElementToPfm(sfmOc:GetTimeFrame(),pfmOc:GetTimeFrame())
	pfmOc:SetMaterial(sfmOc:GetMaterial())
	pfmOc:SetTop(sfmOc:GetTop())
	pfmOc:SetLeft(sfmOc:GetLeft())
	pfmOc:SetWidth(sfmOc:GetWidth())
	pfmOc:SetHeight(sfmOc:GetHeight())
	pfmOc:SetFullscreen(sfmOc:IsFullscreen())
end)
sfm.register_element_type_conversion(sfm.ChannelClip,function(converter,sfmCc,pfmCc)
	converter:ConvertElementToPfm(sfmCc:GetTimeFrame(),pfmCc:GetTimeFrame())

	local editorData = pfmCc:GetEditorData()
	local pfmAnim = pfmCc:GetAnimation()
	for _,sfmChannel in ipairs(sfmCc:GetChannels()) do
		local pfmChannel = pfmAnim:AddChannel()
		if(converter:ConvertElementToPfm(sfmChannel,pfmChannel) == false) then
			-- Invalid channel; Just remove it again
			pfmAnim:RemoveChannel(pfmAnim:GetChannelCount() -1)
		else
			-- Keyframes
			local targetPath = pfmChannel:GetTargetPath()
			if(targetPath ~= nil) then
				local editorChannel = editorData:FindChannel(targetPath,true)

				local SFM_HANDLE_MODE_LINEAR_TANGENTS = 1
				local SFM_HANDLE_MODE_FLAT_TANGENTS = 0
				local SFM_HANDLE_MODE_SPLINE_TANGENTS = 2
				local toPragmaHandleMode = {
					[SFM_HANDLE_MODE_LINEAR_TANGENTS] = pfm.udm.KEYFRAME_HANDLE_TYPE_VECTOR,
					[SFM_HANDLE_MODE_FLAT_TANGENTS] = pfm.udm.KEYFRAME_HANDLE_TYPE_FREE,
					[SFM_HANDLE_MODE_SPLINE_TANGENTS] = pfm.udm.KEYFRAME_HANDLE_TYPE_ALIGNED
				}

				local graphCurve = sfmChannel:GetGraphCurve()
				local panimaChannel = panima.Channel(pfmChannel:GetUdmData():Get("times"),pfmChannel:GetUdmData():Get("values"))
				for keyIdx=0,3 do
					local keysTime = graphCurve["GetKeysTime_" .. keyIdx](graphCurve)
					local keysValue = graphCurve["GetKeysValue_" .. keyIdx](graphCurve)
					local keysInTime = graphCurve["GetKeysInTime_" .. keyIdx](graphCurve)
					local keysInDelta = graphCurve["GetKeysInDelta_" .. keyIdx](graphCurve)
					local keysInMode = graphCurve["GetKeysInMode_" .. keyIdx](graphCurve)
					local keysOutTime = graphCurve["GetKeysOutTime_" .. keyIdx](graphCurve)
					local keysOutDelta = graphCurve["GetKeysOutDelta_" .. keyIdx](graphCurve)
					local keysOutMode = graphCurve["GetKeysOutMode_" .. keyIdx](graphCurve)
					for i=1,#keysTime do
						local t = keysTime[i]
						local v = keysValue[i]
						local keyData,ikey = editorChannel:AddKey(t,keyIdx)
						keyData:SetTime(ikey,t)
						-- KeyFrame value doesn't get saved in SFM session (probably to save space), so we have to get it from the animation data instead
						keyData:SetValue(ikey,panimaChannel:GetInterpolatedValue(t))
						keyData:SetEasingMode(ikey,pfm.udm.EASING_MODE_AUTO)
						keyData:SetInterpolationMode(ikey,pfm.udm.INTERPOLATION_BEZIER)

						keyData:SetInTime(ikey,-keysInTime[i])
						keyData:SetInDelta(ikey,keysInDelta[i])
						keyData:SetInHandleType(ikey,toPragmaHandleMode[keysInMode[i]] or pfm.udm.KEYFRAME_HANDLE_TYPE_ALIGNED)

						keyData:SetOutTime(ikey,keysOutTime[i])
						keyData:SetOutDelta(ikey,keysOutDelta[i])
						keyData:SetOutHandleType(ikey,toPragmaHandleMode[keysOutMode[i]] or pfm.udm.KEYFRAME_HANDLE_TYPE_ALIGNED)
					end
				end
			end
		end
	end
end)
sfm.register_element_type_conversion(sfm.Channel,function(converter,sfmC,pfmC)
	local fromElement = sfmC:GetFromElement()
	if(fromElement ~= nil and (fromElement:GetType() == "DmeExpressionOperator" or fromElement:GetType() == "DmePackColorOperator")) then return false end

	local sfmLog = sfmC:GetLog()
	local sfmLayer = sfmLog:GetLayers()[1]
	local type = sfmLayer:GetType()
	if(type == "DmeFloatLogLayer") then type = udm.TYPE_FLOAT
	elseif(type == "DmeVector3LogLayer") then type = udm.TYPE_VECTOR3
	elseif(type == "DmeQuaternionLogLayer") then type = udm.TYPE_QUATERNION
	elseif(type == "DmeIntLogLayer") then type = udm.TYPE_INT32
	elseif(type == "DmeBoolLogLayer") then type = udm.TYPE_BOOLEAN
	else
		console.print_warning("Unsupported log layer type: ",type)
		return
	end

	local values = sfmLayer:GetValues()
	local toAttr = sfmC:GetToAttribute()

	local toElement = sfmC:GetToElement()
	if(toElement == nil) then
		-- pfm.log("Unsupported 'to'-element for channel '" .. sfmC:GetName() .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
	else
		if(toElement:GetType() == "DmeExpressionOperator") then
			local sfmOperator = toElement

			-- Translate toElement/toAttribute to that of the expression operator
			for _,p in ipairs(sfmC:GetParents()) do
				if(p:GetType() == "DmeChannelsClip") then
					for _,channel in ipairs(p:GetChannels()) do
						if(util.is_same_object(channel:GetFromElement(),toElement) and channel:GetFromAttribute() == "result") then
							toElement = channel:GetToElement()
							toAttr = channel:GetToAttribute()
							break
						end
					end
					break
				end
			end

			local variables = {}
			for name,attr in pairs(sfmOperator:GetDMXElement():GetAttributes()) do
				if(name ~= "name" and name ~= "spewresult" and name ~= "result" and name ~= "expr" and name ~= "value") then
					local val = attr:GetValue()
					if(toElement ~= nil and toElement:GetType() == "DmeCamera" and toAttr:lower() == "fieldofview") then
						val = sfm.convert_source_fov_to_pragma(val)
					end
					variables[name] = val
				end
			end
			local expr = sfm.convert_math_expression_to_pragma(sfmOperator:GetExpr(),variables)
			pfmC:SetExpression(expr)
		elseif(toElement:GetType() == "DmePackColorOperator") then
			for _,p in ipairs(sfmC:GetParents()) do
				if(p:GetType() == "DmeChannelsClip") then
					for _,channel in ipairs(p:GetChannels()) do
						if(util.is_same_object(channel:GetFromElement(),sfmC:GetToElement()) and channel:GetFromAttribute() == "color") then
							toElement = channel:GetToElement()
							break
						end
					end
					break
				end
			end
		end

		local origToElement = sfmC:GetToElement()
		local gm = toElement:FindParent("DmeGameModel") or false
		local c = not gm and toElement:FindParent("DmeCamera") or false
		local pj = not c and toElement:FindParent("DmeProjectedLight") or false
		local ps = not pj and toElement:FindParent("DmeGameParticleSystem") or false
		local actor = gm or c or pj or ps

		local pfmPropPath
		if(actor ~= false and toElement:GetType() == "DmeTransform") then
			if(util.is_same_object(actor:GetTransform(),toElement)) then
				local cpath = "ec/pfm_actor/"
				if(toAttr == "position") then pfmPropPath = cpath .. "position"
				elseif(toAttr == "orientation") then pfmPropPath = cpath .. "rotation"
				elseif(toAttr == "scale") then pfmPropPath = cpath .. "scale" end
			end
		end
		
		if(pfmPropPath == nil) then
			if(gm ~= false) then
				if(toElement:GetType() == "DmeTransform") then
					local final = false
					if(toElement:GetName() == "viewTarget") then
						if(toAttr == "position") then
							pfmPropPath = "ec/eye/viewTarget"
						elseif(toAttr == "rotation") then
							-- TODO: Does this actually serve a purpose?
							return false
						end
					else
						for _,sfmBone in ipairs(gm:GetBones()) do
							if(util.is_same_object(toElement,sfmBone)) then
								local name = string.remove_whitespace(sfmBone:GetName()) -- Format: "name (boneName)"
								local boneNameStart = name:find("%(")
								local boneNameEnd = name:match('.*()' .. "%)") -- Reverse find
								if(boneNameStart ~= nil and boneNameEnd ~= nil) then
									local boneName = name:sub(boneNameStart +1,boneNameEnd -1)
									local cpath = "ec/animated/bone/" .. boneName .. "/"

									if(toAttr == "position") then pfmPropPath = cpath .. "position"
									elseif(toAttr == "orientation") then pfmPropPath = cpath .. "rotation"
									elseif(toAttr == "scale") then pfmPropPath = cpath .. "scale" end
								else
									pfm.log("Invalid format for bone name '" .. name .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
									return false
								end
								break
							end
						end
					end
				elseif(toElement:GetType() == "DmeGlobalFlexControllerOperator") then
					local name = toElement:GetName()
					pfmPropPath = "ec/flex/flexController/" .. name
				elseif(toAttr == "localViewTargetFactor") then
					pfmPropPath = "ec/eye/localViewTargetFactor"
				end
			elseif(c ~= false) then
				local sfmAttrToPfm = {
					["fieldofview"] = "fov",
					["znear"] = "nearZ",
					["zfar"] = "farZ",
					["focaldistance"] = "focalDistance"
				}
				local translatedAttr = sfmAttrToPfm[toAttr:lower()]
				if(translatedAttr ~= nil) then pfmPropPath = "ec/camera/" .. translatedAttr end
			elseif(pj ~= false) then
				if(origToElement:GetType() == "DmePackColorOperator") then
					if(toAttr ~= "red" and toAttr ~= "green" and toAttr ~= "blue" and toAttr ~= "alpha") then
						pfm.log("Unsupported pack color operator for to-attribute '" .. toAttr .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
						return false
					end
					pfmPropPath = "ec/color/color?components=" .. toAttr
				else
					local lToAttr = toAttr:lower()
					if(lToAttr == "intensity") then
						pfmPropPath = "ec/light/intensity"
					elseif(lToAttr == "maxdistance") then
						pfmPropPath = "ec/radius/radius"
					elseif(lToAttr == "horizontalfov" or lToAttr == "verticalfov") then
						pfmPropPath = "ec/light_spot/outerConeAngle"
					end
				end
			elseif(ps ~= false) then
				-- TODO
			end
		end

		if(pfmPropPath == nil) then console.print_warning("Unsupported attribute for element " .. tostring(toElement) .. ": " .. toAttr .. " (of channel clip '" .. sfmC:GetName() .. "')") return false end

		if(actor == false) then error("Invalid actor for attribute '" .. toAttr .. "' of element " .. tostring(toElement) .. " of channel clip '" .. sfmC:GetName() .. "'!") end

		local pfmActorId = converter.m_sfmObjectToPfmActor[actor]
		if(pfmActorId == nil) then error("No PFM actor for attribute '" .. toAttr .. "' of element " .. tostring(toElement) .. "!") end

		local anim = pfmC:GetAnimation()
		local clip = anim:GetAnimationClip()
		local actor = tostring(clip:GetActorId())
		if(actor == tostring(util.Uuid(""))) then
			-- No actor assigned yet
			clip:SetActor(pfmActorId)
		elseif(actor ~= pfmActorId) then
			error("Actor mismatch for attribute '" .. toAttr .. "' of element " .. tostring(toElement) .. "!")
		end
		local c = ents.PanimaComponent.parse_component_channel_path(panima.Channel.Path(pfmPropPath))
		if(c == nil) then
			error("Invalid channel path '" .. pfmPropPath .. "' for attribute '" .. toAttr .. "' of element " .. tostring(toElement) .. "!")
		end
		pfmC:SetTargetPath(pfmPropPath)
	end
	pfmC:GetUdmData():SetArrayValues("times",udm.TYPE_FLOAT,sfmLayer:GetTimes(),udm.TYPE_ARRAY_LZ4)
	pfmC:GetUdmData():SetArrayValues("values",type,values,udm.TYPE_ARRAY_LZ4)
end)

local rotN90Yaw = EulerAngles(0,-90,0):ToQuaternion()
local function convert_root_bone_pos(pos,isStaticModel)
	-- Root bones seem to be in a different coordinate system than everything else in the source engine?
	-- I don't know why that is the case, but we have to take it into account here.
	pos:Set(pos.x,-pos.y,-pos.z)

	if(isStaticModel == true) then return end
	-- Dynamic models and static models require different rotations, I am not sure why that is the case though.
	pos:Rotate(rotN90Yaw)
end
local rot180Pitch = EulerAngles(180,0,0):ToQuaternion()
local function convert_root_bone_rot(rot,isStaticModel)
	local newRot = rot180Pitch *rot
	rot:Set(newRot.w,newRot.x,newRot.y,newRot.z)

	if(isStaticModel == true) then return end
	-- Dynamic models and static models require different rotations, I am not sure why that is the case though.
	rot:Set(rotN90Yaw *rot)
end

function sfm.ProjectConverter:ConvertSession(sfmSession)
	local pfmSession = udm.create_property_from_schema(pfm.udm.SCHEMA,"Session")
	self.m_pfmProject:SetSession(pfmSession)

	-- Settings
	local sfmSettings = sfmSession:GetSettings():GetRenderSettings()
	local pfmSettings = pfmSession:GetSettings():GetRenderSettings()
	self:ConvertElementToPfm(sfmSettings,pfmSettings)

	-- Active clip
	local sfmClip = sfmSession:GetActiveClip()
	local pfmClip = pfmSession:AddClip()
	pfmSession:SetActiveClip(pfmClip)
	self:ConvertElementToPfm(sfmClip,pfmClip)

	local subClipTrackGroup = pfmClip:AddTrackGroup()
	self:ConvertElementToPfm(sfmClip:GetSubClipTrackGroup(),subClipTrackGroup)

	-- Convert animation transforms
	local function iterate_track_groups(pfmClip)
		for _,trackGroup in ipairs(pfmClip:GetTrackGroups()) do
			for _,track in ipairs(trackGroup:GetTracks()) do
				for _,clip in ipairs(track:GetFilmClips()) do
					iterate_track_groups(clip)
				end
			end
		end

		local animTrack = pfmClip:FindAnimationChannelTrack()
		if(animTrack ~= nil) then
			local function transformChannelValues(channel,transformFunc,udmType)
				local values = channel:GetValues()
				for i,val in ipairs(values) do
					values[i] = transformFunc(val)
				end
				channel:GetUdmData():SetArrayValues("values",udmType,values,udm.TYPE_ARRAY_LZ4)

				-- TODO: We also have to translate the handle delta values
				--[[local editorChannel
				if(editorChannel ~= nil) then
					for keyIdx=0,3 do

					end
				end]]
			end
			for _,animClip in ipairs(animTrack:GetAnimationClips()) do
				local anim = animClip:GetAnimation()
				local actor = animClip:GetActor()
				if(actor ~= nil) then
					local mdl
					local mdlC = actor:FindComponent("model")
					if(mdlC ~= nil) then
						local mdlName = mdlC:GetMemberValue("model")
						if(mdlName ~= nil) then mdl = game.load_model(mdlName) end
					end
					for _,channel in ipairs(anim:GetChannels()) do
						local targetPath = channel:GetTargetPath()
						local componentName,componentPath = ents.PanimaComponent.parse_component_channel_path(panima.Channel.Path(targetPath))
						if(componentName == "animated") then
							local pathComponents = string.split(componentPath:GetString(),"/")
							if(#pathComponents == 3 and pathComponents[1] == "bone") then
								local boneName = pathComponents[2]
								local boneId = mdl and mdl:LookupBone(boneName) or -1
								local isRootBone = (boneId ~= -1) and mdl:IsRootBone(boneId) or false

								local type = pathComponents[3]
								if(type == "position") then
									transformChannelValues(channel,function(val)
										val = sfm.convert_source_anim_set_position_to_pragma(val)
										if(isRootBone) then
											convert_root_bone_pos(val,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
										end
										return val
									end,udm.TYPE_VECTOR3)
								elseif(type == "rotation") then
									transformChannelValues(channel,function(val)
										val = sfm.convert_source_anim_set_rotation_to_pragma(val)
										if(isRootBone) then
											convert_root_bone_rot(val,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
										end
										return val
									end,udm.TYPE_QUATERNION)
								elseif(type == "scale") then
									transformChannelValues(channel,function(val)
										return Vector(val,val,val)
									end,udm.TYPE_VECTOR3)
								end
							end
						elseif(componentName == nil or componentPath == nil) then console.print_error("Unable to parse component channel path for '" .. targetPath .. "'!")
						else
							local pathComponents = string.split(componentPath:GetString(),"/")
							if(#pathComponents >= 1) then
								if(componentName == "eye" and pathComponents[1] == "viewTarget") then
									transformChannelValues(channel,function(val)
										return sfm.convert_source_transform_position_to_pragma(val)
									end,udm.TYPE_VECTOR3)
								elseif(componentName == "pfm_actor" or componentName == "transform") then
									if(pathComponents[1] == "position") then
										transformChannelValues(channel,function(val)
											return sfm.convert_source_transform_position_to_pragma(val)
										end,udm.TYPE_VECTOR3)
									elseif(pathComponents[1] == "rotation") then
										transformChannelValues(channel,function(val)
											return sfm.convert_source_transform_rotation_to_pragma_special(nil,val)
										end,udm.TYPE_QUATERNION)
									end
								elseif(componentName == "light_spot") then
									if(pathComponents[1] == "outerConeAngle" or pathComponents[1] == "innerConeAngle") then
										transformChannelValues(channel,function(val)
											return val *0.5
										end,udm.TYPE_FLOAT)
									end
								elseif(componentName == "camera") then
									if(pathComponents[1] == "fov") then
										transformChannelValues(channel,function(val)
											return sfm.convert_source_fov_to_pragma(val)
										end,udm.TYPE_FLOAT)
									end
								elseif(componentName == "flex") then
									local flexName = pathComponents[2]
									if(mdl ~= nil) then
										local flexId = mdl:LookupFlexController(flexName)
										if(flexId ~= -1) then
											local flexData = mdl:GetFlexController(flexId)
											local range = flexData.max -flexData.min
											local function remap_value(val)
												-- Remap range [0,1] to [min,max]
												val = val *range
												val = val +flexData.min
												return val
											end
											transformChannelValues(channel,function(val)
												return remap_value(val)
											end,udm.TYPE_FLOAT)
										else
											pfm.log("Flex '" .. flexName .. "' of model '" .. mdl:GetName() .. "' does not exist! Ignoring...",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
										end
									else
										pfm.log("Model of actor '" .. actor:GetName() .. "' could not be loaded! Flex controller values will be incorrect!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
									end
								end
							end
						end
					end
				end
			end
		end
	end
	iterate_track_groups(pfmClip)
end

function sfm.ProjectConverter:GetPFMActor(pfmComponent)
	return self.m_sfmObjectToPfmActor[pfmComponent]
end
function sfm.ProjectConverter:CachePFMActor(pfmComponent,pfmActor)
	self.m_sfmObjectToPfmActor[pfmComponent] = pfmActor
end
function sfm.ProjectConverter:CreateActor(sfmComponent,pfmParentDag)
	local pfmComponent = self:ConvertNewElement(sfmComponent)
	local actor = self:GetPFMActor(pfmComponent) -- Check if this component has already been associated with an actor
	if(actor ~= nil) then return actor,false end
	actor = fudm.create_element(fudm.ELEMENT_TYPE_PFM_ACTOR)
	if(sfmComponent:GetType() == "DmeCamera") then
		if(pfmParentDag ~= nil) then actor:ChangeName(pfmParentDag:GetName()) end -- pfmComponent:GetName()) -- TODO: Remove suffix (e.g. _model)
	else
		actor:ChangeName(sfmComponent:GetName())
	end
	actor:SetVisible(sfmComponent:IsVisible())

	local transformType = sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL
	-- TODO: Unsure about light sources; Confirm that this is correct!
	if(sfmComponent:GetType() == "DmeCamera" or sfmComponent:GetType() == "DmeGameParticleSystem" or sfmComponent:GetType() == "DmeProjectedLight") then transformType = sfm.ProjectConverter.TRANSFORM_TYPE_ALT end

	actor:SetTransformAttr(self:ConvertNewElement(sfmComponent:GetTransform(),transformType))
	actor:AddComponent(pfmComponent)
	self:CachePFMActor(pfmComponent,actor)

	if(sfmComponent:GetType() == "DmeGameModel") then
		-- Locate animation set associated with this actor
		local elFilmClip
		local filmClipParentLevel = math.huge
		local iterated = {}
		local function find_parent_film_clip(el,level)
			if(iterated[el] ~= nil) then return end
			iterated[el] = true
			if(el:GetType() == "DmeFilmClip") then
				if(level < filmClipParentLevel) then
					elFilmClip = el
					filmClipParentLevel = level
				end
				return
			end
			for _,parent in ipairs(el:GetParents()) do
				find_parent_film_clip(parent,level +1)
			end
		end
		find_parent_film_clip(sfmComponent,0)
		if(elFilmClip ~= nil) then
			local animSets = elFilmClip:GetAnimationSets()
			for _,animSet in ipairs(animSets) do
				if(util.is_same_object(animSet:GetGameModel(),sfmComponent)) then
					-- Found animation set. Now we'll move the operators from the animation set to our new actor.
					for _,op in ipairs(animSet:GetOperators()) do
						actor:GetOperatorsAttr():PushBack(self:ConvertNewElement(op))
					end
					break
				end
			end
		end
	end
	return actor,true
end
function sfm.ProjectConverter:GetPFMElement(element)
	return self.m_sfmElementToPfmElement[element]
end
local function convert_bone_transforms(filmClip,processedObjects,mdlMsgCache)
	for _,actor in ipairs(filmClip:GetActorList()) do
		if(processedObjects[actor] == nil) then
			processedObjects[actor] = true
			for _,component in ipairs(actor:GetComponents():GetTable()) do
				if(component:GetType() == fudm.ELEMENT_TYPE_PFM_MODEL) then
					local mdlName = asset.normalize_asset_name(component:GetModelName(),asset.TYPE_MODEL)
					local mdl = game.load_model(mdlName)
					if(mdl == nil and mdlMsgCache[mdlName] == nil) then
						mdlMsgCache[mdlName] = true
						pfm.log("Unable to load model '" .. mdlName .. "'! Bone transforms for this model will be incorrect!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
					end
					for boneId,bone in ipairs(component:GetBoneList():GetTable()) do
						bone = bone:GetTarget()
						-- TODO: I'm not sure if the index actually corresponds to the bone id, keep this under observation
						local isRootBone = (mdl ~= nil) and mdl:IsRootBone(boneId -1) or false

						local t = bone:GetTransform()
						local pos = t:GetPosition():Copy()
						local rot = t:GetRotation():Copy()
						pos = sfm.convert_source_anim_set_position_to_pragma(pos)
						rot = sfm.convert_source_anim_set_rotation_to_pragma(rot)
						if(isRootBone) then
							convert_root_bone_pos(pos,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
							convert_root_bone_rot(rot,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
						end
						t:SetPosition(pos)
						t:SetRotation(rot)
					end
				end
			end
		end
	end
end
local function apply_post_processing(converter,project,filmClip,processedObjects)
	-- Root bones in the source engine use a different coordinate system for whatever reason, so we
	-- have to do some additional conversion in post-processing.
	processedObjects = processedObjects or {}
	local mdlMsgCache = {}
	convert_bone_transforms(filmClip,processedObjects,mdlMsgCache)
	
	local pfmElToSfm = {}
	for sfm,pfm in pairs(converter.m_sfmElementToPfmElement) do
		pfmElToSfm[pfm] = sfm
	end
	for _,trackGroup in ipairs(filmClip:GetTrackGroups():GetTable()) do
		pfm.log("Processing track group '" .. tostring(trackGroup) .. "'...",pfm.LOG_CATEGORY_PFM_CONVERTER)
		for _,track in ipairs(trackGroup:GetTracks():GetTable()) do
			pfm.log("Processing track '" .. tostring(track) .. "'...",pfm.LOG_CATEGORY_PFM_CONVERTER)
			for _,channelClip in ipairs(track:GetChannelClips():GetTable()) do
				local channels = channelClip:GetChannels()
				local numChannels = #channels
				pfm.log("Processing channel clip '" .. tostring(channelClip) .. "' with " .. numChannels .. " channels...",pfm.LOG_CATEGORY_PFM_CONVERTER)

				local channelsRemove = {}
				for i,channel in ipairs(channels:GetTable()) do
					local sfmFromElement = pfmElToSfm[channel]:GetFromElement()
					if(sfmFromElement ~= nil and sfmFromElement:GetType() == "DmePackColorOperator") then
						for _,channelOther in ipairs(channels:GetTable()) do
							local sfmToElement = pfmElToSfm[channelOther]:GetToElement()
							if(util.is_same_object(sfmToElement,sfmFromElement)) then
								local toAttr = channelOther:GetToAttribute()
								channelOther:SetTargetPath("ec/color/color?components=" .. toAttr)
								channelOther:SetToElement(channel:GetToElement())
								channelOther:SetToAttribute("color")
							end
						end
						table.insert(channelsRemove,i)
					elseif(#channel:GetTargetPath() == 0) then
						local toElement = channel:GetToElement()
						if(toElement ~= nil) then
							local toAttr = channel:GetToAttribute()
							local type = toElement:GetType()
							local handled = true
							local function isTransformAttr()
								local p = toElement:FindParent(function(p) return p:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR end) or nil
								if(p ~= nil and util.is_same_object(p:GetTransform(),toElement)) then return true end
								return false
							end
							local function getBoneEl()
								return toElement:FindParent(function(p) return p:GetType() == fudm.ELEMENT_TYPE_PFM_BONE end)
							end
							if(toAttr == "position") then
								-- debug.print(toElement:GetName(),toAttr)
								if(isTransformAttr()) then
									channel:SetTargetPath("ec/transform/position")
								else
									local elBone = getBoneEl()
									if(elBone ~= nil) then channel:SetTargetPath("ec/animated/bone/" .. elBone:GetName() .. "/position") end
								end
							elseif(toAttr == "rotation") then
								if(isTransformAttr()) then
									channel:SetTargetPath("ec/transform/rotation")
								else
									local elBone = getBoneEl()
									if(elBone ~= nil) then channel:SetTargetPath("ec/animated/bone/" .. elBone:GetName() .. "/rotation") end
								end
							elseif(toAttr == "scale") then
								if(isTransformAttr()) then
									channel:SetTargetPath("ec/transform/scale")
								else
									local elBone = getBoneEl()
									if(elBone ~= nil) then channel:SetTargetPath("ec/animated/bone/" .. elBone:GetName() .. "/scale") end
								end

								-- SFM uses floats for scale, PFM uses Vector3, so we'll have to translate the values
								local log = channel:GetLog()
								local layer = log:GetLayers():Get(1)
								local newValues = {}
								local layerValues = layer:GetValues()
								local oldValues = layerValues:GetTable():ToTable()
								layerValues:SetValueType(util.VAR_TYPE_VECTOR)
								layerValues:GetTable():Reserve(#oldValues)
								for _,v in ipairs(oldValues) do
									v = Vector(v,v,v)
									layerValues:PushBack(v)
								end
							else
								if(toAttr == "flexWeight") then
									channel:SetTargetPath("ec/flex/flexController/" .. toElement:GetName())
								end
								if(type == fudm.ELEMENT_TYPE_PFM_SPOT_LIGHT or type == fudm.ELEMENT_TYPE_PFM_POINT_LIGHT) then
									if(toAttr == "radius") then channel:SetTargetPath("ec/radius/radius")
									elseif(toAttr == "intensity") then channel:SetTargetPath("ec/light/intensity")
									elseif(toAttr == "color") then channel:SetTargetPath("ec/color/color")
									else handled = false end
								elseif(type == fudm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT) then
									if(toAttr == "intensity") then channel:SetTargetPath("ec/light/intensity")
									elseif(toAttr == "color") then channel:SetTargetPath("ec/color/color")
									else handled = false end
								elseif(type == fudm.ELEMENT_TYPE_PFM_CAMERA) then
									if(toAttr == "fov") then channel:SetTargetPath("ec/camera/fov")
									elseif(toAttr == "zNear") then channel:SetTargetPath("ec/camera/nearz")
									elseif(toAttr == "zFar") then channel:SetTargetPath("ec/camera/farz")
									else handled = false end
								end
							end
							if(handled == false) then
								pfm.log("Animation channel '" .. tostring(channel) .. "' has to-attribute '" .. toAttr .. "', which is currently not supported!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
							end
						end
					end
					local toElement = channel:GetToElement()
					if(toElement ~= nil and #channelClip:GetActor() == 0) then
						local actor = toElement:FindParent(function(p) return p:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR end) or nil
						if(actor ~= nil) then
							channelClip:SetActor(actor:GetUniqueId())
						end
					end
					-- TODO: If channel clip has no channels, determine actor by name?
				end
				table.sort(channelsRemove,function(a,b) return b < a end)
				for _,i in ipairs(channelsRemove) do
					channels:Remove(i)
				end

				-- Note: This is commented because it causes issues with some channels that use expression operators (e.g. fov/dof/etc.)
				-- I don't remember what this block was for in the first place, if any problems should occur by this being commented,
				-- uncomment it, but also make sure it works properly with expression operators!
				--[[local i = 1
				while(i < numChannels) do
					local channel = channels:Get(i)
					local name = channel:GetName()
					-- We have no use for scaled channels, so we'll get rid of them to make things easier for us.
					if(name:sub(1,7) == "scaled_" and name:sub(-8) == "_channel") then
						local fromElement = channel:GetFromElement()
						local lo = fromElement:GetProperty("lo"):GetValue()
						local hi = fromElement:GetProperty("hi"):GetValue()
						for _,channelOther in ipairs(channelClip:GetChannels():GetTable()) do
							if(util.is_same_object(channelOther:GetToElement(),channel:GetFromElement())) then
								local log = channelOther:GetLog()
								for _,layer in ipairs(log:GetLayers():GetTable()) do
									local values = layer:GetValues()
									for i=1,#values do
										local value = math.lerp(lo,hi,values:Get(i))
										values:Set(i,value)
									end
								end
							end
						end
						channels:Remove(i)
						numChannels = numChannels -1
					else i = i +1 end
				end]]

				for _,channel in ipairs(channelClip:GetChannels():GetTable()) do
					-- pfm.log("Processing channel '" .. tostring(channel) .. "'...",pfm.LOG_CATEGORY_PFM_CONVERTER)
					local toElement = channel:GetToElement()
					local toAttr = channel:GetToAttribute()
					if(toElement ~= nil and toElement:GetType() == fudm.ELEMENT_TYPE_PFM_CAMERA) then
						if(string.compare(toAttr,"focalDistance",false)) then toElement:SetDepthOfFieldEnabled(true)
						elseif(string.compare(toAttr,"fov",false)) then
							local log = channel:GetLog()
							log:SetDefaultValue(sfm.convert_source_fov_to_pragma(log:GetDefaultValue()))
							--[[for _,layer in ipairs(log:GetLayers():GetTable()) do
								if(processedObjects[layer] == nil) then
									processedObjects[layer] = true
									local values = layer:GetValues()
									local t = values:GetTable()
									for i=1,#t do
										local value = values:Get(i)
										values:Set(i,sfm.convert_source_fov_to_pragma(value))
									end
								end
							end]]
						end
					end

					if(toElement ~= nil and sfm.is_udm_element_entity_component(toElement) and toElement:GetChild(toAttr) == nil) then
						-- Some attributes (like visibility) are stored in the SFM GameModel/Camera/etc. elements. In Pragma these are
						-- components of an actor, and these attributes are stored in the actor, not the components, so we have to
						-- redirect the reference to the actor.
						local actor = toElement:FindParent(function(p) return p:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR end) or nil
						if(actor ~= nil) then
							channel:SetToElement(actor)
							toElement = actor
						end
					end

					local isPosTransform = (toAttr == "position")
					local isRotTransform = (toAttr == "rotation")
					if(toElement ~= nil and toElement:GetType() == fudm.ELEMENT_TYPE_TRANSFORM and (isPosTransform or isRotTransform)) then
						local isBoneTransform = false
						local pfmModel
						local pfmBone
						if(toElement ~= nil and toElement:GetType() == fudm.ELEMENT_TYPE_TRANSFORM) then
							local parent = toElement:FindParentElement()
							if(parent ~= nil and parent:GetType() == fudm.ELEMENT_TYPE_PFM_BONE) then
								pfmBone = parent
								pfmModel = parent:GetModelComponent()
								isBoneTransform = (pfmModel ~= nil)
							end
						end
						if(isBoneTransform) then
							local boneName = pfmBone:GetName()
							local mdlName = pfmModel:GetModelName()
							local mdl = pfmModel:GetModel()
							local boneId = mdl and mdl:LookupBone(boneName) or -1
							local isRootBone = (boneId ~= -1) and mdl:IsRootBone(boneId) or false
							if(mdl == nil and mdlMsgCache[mdlName] == nil) then
								mdlMsgCache[mdlName] = true
								pfm.log("Unable to load model '" .. mdlName .. "'! Bone transforms for this model will be incorrect!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
							end
							if(mdl ~= nil and boneId == -1) then
								pfm.log("Unknown bone '" .. boneName .. "' of model '" .. mdlName .. "'!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
							end

							local log = channel:GetLog()
							if(isPosTransform) then
								local value = sfm.convert_source_anim_set_position_to_pragma(log:GetDefaultValue())
								if(isRootBone) then
									convert_root_bone_pos(value,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
								end
								log:SetDefaultValue(value)
							else
								local value = sfm.convert_source_anim_set_rotation_to_pragma(log:GetDefaultValue())
								if(isRootBone) then
									convert_root_bone_rot(value,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
								end
								log:SetDefaultValue(value)
							end
							for _,layer in ipairs(log:GetLayers():GetTable()) do
								if(processedObjects[layer] == nil) then
									processedObjects[layer] = true
									local values = layer:GetValues()
									for i=1,#values do
										local value = values:Get(i)
										if(isPosTransform) then
											value = sfm.convert_source_anim_set_position_to_pragma(value)
											if(isRootBone) then
												convert_root_bone_pos(value,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
											end
											values:Set(i,value)
										else
											value = sfm.convert_source_anim_set_rotation_to_pragma(value)
											if(isRootBone) then
												convert_root_bone_rot(value,mdl:HasFlag(game.Model.FLAG_BIT_INANIMATE))
											end
											values:Set(i,value)
										end
									end
								end
							end
						else
							local actor = toElement and toElement:FindParent(function(p) return p:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR end) or nil
							local isCamera = false
							if(actor ~= nil) then
								for _,component in ipairs(actor:GetComponents():GetTable()) do
									if(component:GetType() == fudm.ELEMENT_TYPE_PFM_CAMERA) then
										isCamera = true
										break
									end
								end
							end

							local log = channel:GetLog()
							if(isCamera) then
								if(isPosTransform) then
									log:SetDefaultValue(sfm.convert_source_transform_position_to_pragma(log:GetDefaultValue()))
								else
									log:SetDefaultValue(sfm.convert_source_transform_rotation_to_pragma2(log:GetDefaultValue()))
								end
							else
								if(isPosTransform) then
									log:SetDefaultValue(sfm.convert_source_transform_position_to_pragma(log:GetDefaultValue()))
								else
									log:SetDefaultValue(sfm.convert_source_transform_rotation_to_pragma_special(actor,log:GetDefaultValue()))
								end
							end
							for _,layer in ipairs(log:GetLayers():GetTable()) do
								if(processedObjects[layer] == nil) then
									processedObjects[layer] = true
									local values = layer:GetValues()
									for i=1,#values do
										local value = values:Get(i)
										-- TODO: Note: These conversions have been confirmed to work with
										-- the skydome test session, but it's unclear if they work
										-- in all cases! Keep it under observation!
										if(isCamera) then
											if(isPosTransform) then
												values:Set(i,sfm.convert_source_transform_position_to_pragma(value))
											else
												values:Set(i,sfm.convert_source_transform_rotation_to_pragma2(value))
											end
										else
											if(isPosTransform) then
												values:Set(i,sfm.convert_source_transform_position_to_pragma(value))
											else
												values:Set(i,sfm.convert_source_transform_rotation_to_pragma_special(actor,value))
											end
										end
									end
								end
							end
						end
					end
				end
			end
			for _,childFilmClip in ipairs(track:GetFilmClips():GetTable()) do
				apply_post_processing(converter,project,childFilmClip,processedObjects)
			end
		end
	end						
end
function sfm.ProjectConverter:ApplyPostProcessing()
	pfm.log("Applying post-processing...",pfm.LOG_CATEGORY_PFM_CONVERTER)

	local session = self.m_pfmProject:GetSession()
	for _,filmClip in ipairs(session:GetClips()) do
		local trackGroup = filmClip:FindTrackGroup("subClipTrackGroup")
		if(trackGroup == nil) then
			trackGroup = filmClip:AddTrackGroup()
			trackGroup:SetName("subClipTrackGroup")
		end

		local track = trackGroup:FindTrack("Film")
		if(track == nil) then
			track = trackGroup:AddTrack()
			track:SetName("Film")
		end

		for _,subFilmClip in ipairs(track:GetFilmClips()) do
			local channelTrackGroup = subFilmClip:FindTrackGroup("channelTrackGroup")
			if(channelTrackGroup == nil) then
				channelTrackGroup = subFilmClip:AddTrackGroup()
				channelTrackGroup:SetName("channelTrackGroup")
			end

			local track = channelTrackGroup:FindTrack("animSetEditorChannels")
			if(track == nil) then
				track = channelTrackGroup:AddTrack()
				track:SetName("animSetEditorChannels")
			end
		end
	end

	if(true) then return end
	-- Obsolete
	local function iterate_session(el,type,callback,iterated)
		iterated = iterated or {}
		for name,child in pairs(el:GetChildren()) do
			if(child:IsElement() and iterated[child] == nil) then
				iterated[child] = true
				iterate_session(child,type,callback,iterated)
			end
			if(child:GetType() == type) then callback(child) end
		end
	end

	local project = self:GetPFMProject()
	for _,session in ipairs({project:GetSession()}) do
		iterate_session(session,fudm.ELEMENT_TYPE_TRANSFORM,function(elTransform)
			-- The "overrideParent" attribute of some transforms may be pointing to an actor component, but
			-- we want it to point to the actor instead.
			local overrideParent = elTransform:GetOverrideParent()
			if(overrideParent ~= nil) then
				if(sfm.is_udm_element_entity_component(overrideParent)) then
					local overrideParentActor = overrideParent:FindParentElement()
					elTransform:SetOverrideParent((overrideParentActor ~= nil) and fudm.create_reference(overrideParentActor) or nil)
				end
			end
		end)

		for _,filmClip in ipairs(session:GetClips()) do
			apply_post_processing(self,project,filmClip)
		end
	end
	pfm.log("Generating particle system files for embedded particle systems...",pfm.LOG_CATEGORY_PFM_CONVERTER)
	self:GenerateEmbeddedParticleSystemFile()

	-- SFM uses scalar scaling factors, Pragma uses 3D vectors, so we'll have to do some conversions.
	pfm.log("Converting scalar scaling factors to vectors...",pfm.LOG_CATEGORY_PFM_CONVERTER)
	sfm.convert_scale_factors_to_vectors(project)

	pfm.log("Fixing element references...",pfm.LOG_CATEGORY_PFM_CONVERTER)
	sfm.fix_element_references(project)

	-- Build scene graph
	local groups = {}
	project:GetUDMRootNode():FindElementsByType(fudm.ELEMENT_TYPE_PFM_GROUP,groups)
	for _,group in ipairs(groups) do
		local elParent = group:FindParentElement(function(el) return el:GetType() == fudm.ELEMENT_TYPE_PFM_FILM_CLIP end)
		if(elParent ~= nil) then
			-- We'll assume the 'group' element is a scene
			for _,actor in ipairs(group:GetActors():GetTable()) do
				actor:BuildSceneParents(group)
			end
		end
	end
end

sfm.get_pfm_conversion_data = function(sfmType)
	return g_sfmToPfmConversion[(type(sfmType) == "string") and sfmType or util.get_type_name(sfmType)]
end

sfm.get_pfm_conversion_function = function(sfmType)
	local data = sfm.get_pfm_conversion_data(sfmType)
	return data and data[1] or nil
end

function sfm.ProjectConverter:ConvertElement(sfmElement,pfmElement,...)
	local data = sfm.get_pfm_conversion_data(util.get_type_name(sfmElement))
	if(data == nil) then
		pfm.error("No PFM conversion function exists for SFM element of type '" .. util.get_type_name(sfmElement) .. "'!")
	end
	-- DMX element may be invalid if it wasn't set in the DMX project file
	--[[if(sfmElement:GetDMXElement() == nil) then
		pfm.error("Attempted to convert SFM element '" .. sfmElement:GetName() .. "' of type '" .. util.get_type_name(sfmElement) .. "', but was not loaded from DMX element!")
	end]]
	pfmElement:ChangeName(sfmElement:GetName())
	self.m_sfmElementToPfmElement[sfmElement] = pfmElement -- Has to be cached before conversion function is called!
	data[1](self,sfmElement,pfmElement,...)
end

function sfm.ProjectConverter:ConvertNewElement(sfmElement,...)
	if(self.m_sfmElementToPfmElement[sfmElement] ~= nil) then
		return self.m_sfmElementToPfmElement[sfmElement],false -- Return cached element
	end
	local data = sfm.get_pfm_conversion_data(util.get_type_name(sfmElement))
	if(data == nil) then
		pfm.error("No PFM conversion function exists for SFM element of type '" .. util.get_type_name(sfmElement) .. "'!")
	end
	local pfmType = data[2]
	if(type(pfmType) == "function") then
		pfmType = pfmType(self,sfmElement)
	end
	local pfmElement = pfmType()
	pfmElement:ChangeName(sfmElement:GetName())
	self:ConvertElement(sfmElement,pfmElement,...)
	return pfmElement,true
end

----------------------

if(true) then return end

-- Obsolete
include("project_converter")

sfm.register_element_type_conversion(sfm.Session,fudm.PFMSession,function(converter,sfmSession,pfmSession)
	local activeClip = sfmSession:GetActiveClip()
	local pfmActiveClip = converter:ConvertNewElement(activeClip)
	pfmSession:SetActiveClip(fudm.create_reference(pfmActiveClip))
	pfmSession:SetSettings(converter:ConvertNewElement(sfmSession:GetSettings()))

	pfmSession:GetClipsAttr():PushBack(pfmActiveClip)
	--[[for _,clipSet in ipairs({sfmSession:GetClipBin(),sfmSession:GetMiscBin()}) do
		for _,clip in ipairs(clipSet) do
			if(clip:GetType() == "DmeFilmClip") then
				pfmSession:GetClipsAttr():PushBack(converter:ConvertNewElement(clip))
			else
				pfm.log("Unsupported session clip type '" .. clip:GetType() .. "'! Skipping...",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
			end
		end
	end]]
end)

sfm.register_element_type_conversion(sfm.Settings,fudm.PFMSettings,function(converter,sfmSettings,pfmSettings)
	pfmSettings:SetRenderSettings(converter:ConvertNewElement(sfmSettings:GetRenderSettings()))
end)

sfm.register_element_type_conversion(sfm.RenderSettings,fudm.PFMRenderSettings,function(converter,sfmRenderSettings,pfmRenderSettings)
	pfmRenderSettings:SetFrameRate(sfmRenderSettings:GetFrameRate())
end)

sfm.register_element_type_conversion(sfm.BookmarkSet,fudm.PFMBookmarkSet,function(converter,sfmBookmarkSet,pfmBookmarkSet)
	for _,bookmark in ipairs(sfmBookmarkSet:GetBookmarks()) do
		pfmBookmarkSet:GetBookmarks():PushBack(converter:ConvertNewElement(bookmark))
	end
end)

sfm.register_element_type_conversion(sfm.Bookmark,fudm.PFMBookmark,function(converter,sfmBookmark,pfmBookmark)
	pfmBookmark:GetTimeRange():SetTime(sfmBookmark:GetTime())
	pfmBookmark:GetTimeRange():SetDuration(sfmBookmark:GetDuration())
	pfmBookmark:SetNote(sfmBookmark:GetNote())
end)

sfm.register_element_type_conversion(sfm.Material,fudm.PFMMaterial,function(converter,sfmMaterial,pfmMaterial)
	pfmMaterial:SetMaterialName(sfmMaterial:GetMtlName())
	local baseTexture = sfmMaterial["Get$basetexture"](sfmMaterial)
	if(baseTexture ~= nil and #baseTexture > 0) then
		pfmMaterial:GetOverrideValuesAttr():Insert("albedo_map",fudm.String(baseTexture))
	end
end)

sfm.register_element_type_conversion(sfm.Color,fudm.Color,function(converter,sfmColor,pfmColor)
	pfmColor:SetValue(sfmColor:GetColor())
end)

sfm.register_element_type_conversion(sfm.TimeFrame,fudm.PFMTimeFrame,function(converter,sfmTimeFrame,pfmTimeFrame)
	pfmTimeFrame:SetStart(sfmTimeFrame:GetStart())
	pfmTimeFrame:SetDuration(sfmTimeFrame:GetDuration())
	pfmTimeFrame:SetOffset(sfmTimeFrame:GetOffset())
	pfmTimeFrame:SetScale(sfmTimeFrame:GetScale())
end)

sfm.register_element_type_conversion(sfm.AnimationSet,fudm.PFMAnimationSet,function(converter,sfmAnimSet,pfmAnimSet)
	-- TODO: This is obsolete!
	-- Flex controls
	--[[for _,sfmControl in ipairs(sfmAnimSet:GetControls()) do
		local pfmControl = converter:ConvertNewElement(sfmControl)
		pfmAnimSet:AddFlexControl(pfmControl)
	end
	
	-- Transform controls
	for _,sfmControl in ipairs(sfmAnimSet:GetTransformControls()) do
		local pfmControl = converter:ConvertNewElement(sfmControl)
		pfmAnimSet:AddTransformControl(pfmControl)
	end]]
end)

sfm.register_element_type_conversion(sfm.Track,fudm.PFMTrack,function(converter,sfmTrack,pfmTrack)
	pfmTrack:SetMuted(sfmTrack:IsMuted())
	pfmTrack:SetVolume(sfmTrack:GetVolume())

	for _,clip in ipairs(sfmTrack:GetFilmClips()) do
		local pfmClip = converter:ConvertNewElement(clip)
		pfmTrack:GetFilmClipsAttr():PushBack(pfmClip)
	end
	
	for _,clip in ipairs(sfmTrack:GetSoundClips()) do
		local pfmClip = converter:ConvertNewElement(clip)
		pfmTrack:GetAudioClipsAttr():PushBack(pfmClip)
	end

	for _,clip in ipairs(sfmTrack:GetOverlayClips()) do
		local pfmClip = converter:ConvertNewElement(clip)
		pfmTrack:GetOverlayClipsAttr():PushBack(pfmClip)
	end
	
	for _,clip in ipairs(sfmTrack:GetChannelClips()) do
		local pfmClip = converter:ConvertNewElement(clip)
		pfmTrack:GetChannelClipsAttr():PushBack(pfmClip)
	end
end)

sfm.register_element_type_conversion(sfm.TrackGroup,fudm.PFMTrackGroup,function(converter,sfmTrackGroup,pfmTrackGroup)
	pfmTrackGroup:SetVisible(sfmTrackGroup:IsVisible())
	pfmTrackGroup:SetMuted(sfmTrackGroup:IsMuted())
	for _,track in ipairs(sfmTrackGroup:GetTracks()) do
		local pfmTrack = converter:ConvertNewElement(track)
		pfmTrackGroup:GetTracksAttr():PushBack(pfmTrack)
	end
end)

sfm.register_element_type_conversion(sfm.Camera,fudm.PFMCamera,function(converter,sfmCamera,pfmCamera)
	pfmCamera:SetFov(sfm.convert_source_fov_to_pragma(sfmCamera:GetFieldOfView()))
	pfmCamera:SetZNear(sfm.source_units_to_pragma_units(sfmCamera:GetZNear()))
	pfmCamera:SetZFar(sfm.source_units_to_pragma_units(sfmCamera:GetZFar()))
	pfmCamera:SetAspectRatio(sfm.ASPECT_RATIO)
	local aperture = sfmCamera:GetAperture()
	if(aperture > 0.0) then
		pfmCamera:SetDepthOfFieldEnabled(true)
		pfmCamera:SetFStop(sfm.convert_source_aperture_to_fstop(aperture))
	end
	pfmCamera:SetFocalDistance(sfm.source_units_to_pragma_units(sfmCamera:GetFocalDistance()))
	pfmCamera:SetSensorSize(36.0)
	pfmCamera:SetApertureBladeCount(3)
end)

sfm.register_element_type_conversion(sfm.Control,fudm.PFMFlexControl,function(converter,sfmControl,pfmControl)
	pfmControl:SetValue(sfmControl:GetValue())
	pfmControl:SetLeftValue(sfmControl:GetLeftValue())
	pfmControl:SetRightValue(sfmControl:GetRightValue())

	local sfmChannel = sfmControl:GetChannel()
	if(sfmChannel ~= nil) then
		local pfmChannel = converter:ConvertNewElement(sfmChannel)
		pfmControl:SetChannelAttr(pfmChannel)
	end
	
	sfmChannel = sfmControl:GetRightValueChannel()
	if(sfmChannel ~= nil) then
		local pfmChannel = converter:ConvertNewElement(sfmChannel)
		pfmControl:SetRightValueChannelAttr(pfmChannel)
	end
	
	sfmChannel = sfmControl:GetLeftValueChannel()
	if(sfmChannel ~= nil) then
		local pfmChannel = converter:ConvertNewElement(sfmChannel)
		pfmControl:SetLeftValueChannelAttr(pfmChannel)
	end
end)

sfm.register_element_type_conversion(sfm.TransformControl,fudm.PFMTransformControl,function(converter,sfmControl,pfmControl)
	local pos = sfmControl:GetValuePosition()
	local rot = sfmControl:GetValueOrientation()
	-- TODO: The Source Engine uses different coordinate systems depending on what we're dealing with.
	-- We need to determine whether or not this is a bone transform, but there's really no good way to do it, so
	-- we'll just check if this is one of the typical known non-bone transforms.
	-- TODO: This will fail if the name has been changed. Find a better way to do this!
	local nonBoneTransforms = {
		["rootTransform"] = true
	}
	local isBoneTransform = not (nonBoneTransforms[pfmControl:GetName()] or false)
	pfmControl:SetValuePosition(isBoneTransform and sfm.convert_source_anim_set_position_to_pragma(pos) or sfm.convert_source_transform_position_to_pragma(pos))
	pfmControl:SetValueRotation(isBoneTransform and sfm.convert_source_anim_set_rotation_to_pragma(rot) or sfm.convert_source_transform_rotation_to_pragma(rot))

	local sfmChannel = sfmControl:GetPositionChannel()
	if(sfmChannel ~= nil) then
		local pfmChannel = converter:ConvertNewElement(sfmChannel)
		pfmControl:SetPositionChannelAttr(pfmChannel)
	end
	
	sfmChannel = sfmControl:GetOrientationChannel()
	if(sfmChannel ~= nil) then
		local pfmChannel = converter:ConvertNewElement(sfmChannel)
		pfmControl:SetRotationChannelAttr(pfmChannel)
	end
end)

sfm.register_element_type_conversion(sfm.GameModel,fudm.PFMModel,function(converter,sfmGameModel,pfmGameModel)
	local mdlName = asset.normalize_asset_name(sfmGameModel:GetPragmaModelPath(),asset.TYPE_MODEL)
	pfmGameModel:SetModelName(mdlName)
	pfmGameModel:SetSkin(sfmGameModel:GetSkin())
	pfmGameModel:SetBodyGroup(sfmGameModel:GetBody())

	local transformToBone = {}
	local function add_child_bones(sfmElement,parent)
		local type = sfmElement:GetType()
		if(type ~= "DmeDag" and type ~= "DmeGameModel") then
			pfm.log("Expected bones of element '" .. pfmGameModel:GetName() .. "' to be of type 'DmeDag', but bone with type '" .. sfmElement:GetType() .. "' found! This is currently not supported!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
			return
		end
		for _,child in ipairs(sfmElement:GetChildren()) do
			local bone = converter:ConvertNewElement(child)

			local name = string.remove_whitespace(child:GetName()) -- Format: "name (boneName)"
			local boneNameStart = name:find("%(")
			local boneNameEnd = name:match('.*()' .. "%)") -- Reverse find
			if(boneNameStart ~= nil and boneNameEnd ~= nil) then
				local boneName = name:sub(boneNameStart +1,boneNameEnd -1)
				bone:ChangeName(boneName)
			else pfm.log("Invalid format for bone name '" .. name .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING) end

			if(parent:GetType() == fudm.ELEMENT_TYPE_PFM_MODEL) then parent:GetRootBonesAttr():PushBack(bone)
			else parent:AddChild(bone) end

			transformToBone[child:GetTransform()] = bone
			transformToBone[child:GetName()] = bone
			add_child_bones(child,bone)
		end
	end
	add_child_bones(sfmGameModel,pfmGameModel)

	for _,node in ipairs(sfmGameModel:GetBones()) do
		local pfmBone = transformToBone[node]
		if(pfmBone == nil) then
			-- Transform in bone list doesn't match transform in child hierarchy.
			-- This can happen if a rig is involved.
			-- In this case we'll attempt to find it by name, although this
			-- isn't reliable as the name can be changed arbitrarily.
			pfmBone = transformToBone[node:GetName()]
		end
		if(pfmBone ~= nil) then
			pfmGameModel:GetBoneListAttr():PushBack(fudm.create_reference(pfmBone))
			-- Note: The transform in the bone hierarchy is not necessarily the actual final transform for the bone,
			-- we'll use the one from the bone list instead.
			pfmBone:SetProperty("transform",converter:ConvertNewElement(node))
		else
			pfm.log("Found bone '" .. node:GetName() .. "' in list of bones for actor '" .. sfmGameModel:GetName() .. "', but bone not found in child hierarchy of that actor! Animation data for this bone will not be available!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
		end
	end

	for _,weight in ipairs(sfmGameModel:GetFlexWeights()) do
		pfmGameModel:GetFlexWeightsAttr():PushBack(fudm.Float(weight))
	end

	for _,node in ipairs(sfmGameModel:GetGlobalFlexControllers()) do
		pfmGameModel:GetGlobalFlexControllersAttr():PushBack(converter:ConvertNewElement(node))
	end

	local mdl = game.load_model(mdlName)
	if(mdl == nil) then
		pfm.log("Unable to load model '" .. mdlName .. "'! Flex controller weights for this model will be incorrect!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
	else
		local numFlexControllerWeights = #sfmGameModel:GetFlexWeights()
		if(numFlexControllerWeights ~= mdl:GetFlexControllerCount()) then
			pfm.log("Number of flex controller weights (" .. numFlexControllerWeights .. ") for model '" .. mdlName .. "' does not match flex controller count of model (" .. mdl:GetFlexControllerCount() .. ")! This may cause issues.",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
			numFlexControllerWeights = mdl:GetFlexControllerCount()
		end
		for i=0,numFlexControllerWeights -1 do
			local fc = mdl:GetFlexController(i)
			pfmGameModel:GetFlexControllerNamesAttr():PushBack(fudm.String(fc and fc.name or ""))
		end
	end

	for _,material in ipairs(sfmGameModel:GetMaterials()) do
		pfmGameModel:GetMaterialOverridesAttr():PushBack(converter:ConvertNewElement(material))
	end
end)

sfm.register_element_type_conversion(sfm.GlobalFlexControllerOperator,fudm.PFMGlobalFlexControllerOperator,function(converter,sfmOp,pfmOp)
	pfmOp:SetFlexWeight(sfmOp:GetFlexWeight())
	pfmOp:SetGameModelAttr(fudm.create_reference(converter:ConvertNewElement(sfmOp:GetGameModel())))
end)

sfm.register_element_type_conversion(sfm.Channel,fudm.PFMChannel,function(converter,sfmChannel,pfmChannel)
	local log = sfmChannel:GetLog()
	local pfmLog = converter:ConvertNewElement(log)
	pfmChannel:SetLogAttr(pfmLog)

	local toAttr = sfmChannel:GetToAttribute()

	-- To
	local toElement = sfmChannel:GetToElement()
	if(toElement == nil) then
		-- pfm.log("Unsupported 'to'-element for channel '" .. sfmChannel:GetName() .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
	elseif(toElement:GetType() ~= "DmePackColorOperator") then
		if(toElement:GetType() == "DmeExpressionOperator") then
			local sfmOperator = toElement

			-- Translate toElement/toAttribute to that of the expression operator
			for _,p in ipairs(sfmChannel:GetParents()) do
				if(p:GetType() == "DmeChannelsClip") then
					for _,channel in ipairs(p:GetChannels()) do
						if(util.is_same_object(channel:GetFromElement(),toElement) and channel:GetFromAttribute() == "result") then
							toElement = channel:GetToElement()
							toAttr = channel:GetToAttribute()
							break
						end
					end
					break
				end
			end

			local variables = {}
			for name,attr in pairs(sfmOperator:GetDMXElement():GetAttributes()) do
				if(name ~= "name" and name ~= "spewresult" and name ~= "result" and name ~= "expr" and name ~= "value") then
					local val = attr:GetValue()
					if(toElement ~= nil and toElement:GetType() == "DmeCamera" and toAttr == "fieldOfView") then
						val = sfm.convert_source_fov_to_pragma(val)
					end
					variables[name] = val
				end
			end
			local expr = sfm.convert_math_expression_to_pragma(sfmOperator:GetExpr(),variables)
			pfmChannel:SetExpression(expr)
		end
		--debug.print("toElement type: " .. tostring(toElement:GetType()))
		local pfmElement = converter:ConvertNewElement(toElement)
		pfmChannel:SetToElementAttr(fudm.create_reference(pfmElement))

		-- Translate attribute
		if(pfmElement ~= nil and toAttr ~= nil) then
			local attrTranslationTable = sfm_attr_to_pragma_table[pfmElement:GetType()]
			if(attrTranslationTable ~= nil) then
				local toAttrL = toAttr:lower()
				if(attrTranslationTable[toAttrL] ~= nil) then
					toAttr = attrTranslationTable[toAttrL]
					pfmChannel:SetToAttribute(toAttr)
				end
			end
		end

		if(pfmElement:GetChild(toAttr) == nil) then
			pfm.log("Invalid to-attribute '" .. toAttr .. "' of element '" .. pfmElement:GetName() .. "' used for channel '" .. pfmChannel:GetName() .. "'!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
		end
	end
	if(toAttr == "orientation") then toAttr = "rotation" end
	pfmChannel:SetToAttribute(toAttr)

	-- From
	local fromAttr = sfmChannel:GetFromAttribute()
	if(fromAttr == "orientation") then fromAttr = "rotation"
	elseif(fromAttr == "valueOrientation") then fromAttr = "valueRotation" end
	pfmChannel:SetFromAttribute(fromAttr)

	local fromElement = sfmChannel:GetFromElement()
	if(fromElement == nil) then
		-- pfm.log("Unsupported 'from'-element for channel '" .. sfmChannel:GetName() .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
	elseif(fromElement:GetType() ~= "DmePackColorOperator") then -- color operators are handled separately
		local pfmElement = converter:ConvertNewElement(fromElement)
		pfmChannel:SetFromElementAttr(fudm.create_reference(pfmElement))

		-- Translate attribute
		if(pfmElement ~= nil and fromAttr ~= nil) then
			local attrTranslationTable = sfm_attr_to_pragma_table[pfmElement:GetType()]
			if(attrTranslationTable ~= nil) then
				local toAttrL = fromAttr:lower()
				if(attrTranslationTable[toAttrL] ~= nil) then
					fromAttr = attrTranslationTable[toAttrL]
					pfmChannel:SetFromAttribute(fromAttr)
				end
			end
		end

		if(pfmElement:GetChild(fromAttr) == nil) then
			pfm.log("Invalid from-attribute '" .. fromAttr .. "' of element '" .. pfmElement:GetName() .. "' used for channel '" .. pfmChannel:GetName() .. "'!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
		end
	end

	--[[local graphCurve = sfmChannel:GetGraphCurve()
	if(graphCurve ~= nil) then
		pfmChannel:SetGraphCurveAttr(converter:ConvertNewElement(graphCurve))
	end]]
end)

sfm.register_element_type_conversion(sfm.ExpressionOperator,fudm.PFMExpressionOperator,function(converter,sfmOperator,pfmOperator) -- Obsolete; Remove me
	--[[local varNames = {}
	for name,attr in pairs(sfmOperator:GetDMXElement():GetAttributes()) do
		if(name ~= "name" and name ~= "spewresult" and name ~= "result" and name ~= "expr" and name ~= "value") then
			table.insert(varNames,name)
			sfm.assign_generic_attribute(name,attr,pfmOperator)
		end
	end
	pfmOperator:SetExpression(sfm.convert_math_expression_to_pragma(sfmOperator:GetExpr(),varNames))
	pfmOperator:SetResult(sfmOperator:GetResult())
	pfmOperator:SetValue(sfmOperator:GetValue())]]
end)

-- TODO: Graph editor element is obsolete; Remove it!
sfm.register_element_type_conversion(sfm.GraphEditorCurve,fudm.PFMGraphCurve,function(converter,sfmGraphCurve,pfmGraphCurve)
	for _,t in ipairs(sfmGraphCurve:GetKeysTime_0()) do
		pfmGraphCurve:GetKeyTimesAttr():PushBack(fudm.Float(t))
	end
	for _,v in ipairs(sfmGraphCurve:GetKeysValue_0()) do
		pfmGraphCurve:GetKeyValuesAttr():PushBack(fudm.Float(v))
	end
end)

sfm.register_element_type_conversion(sfm.LogLayer,fudm.PFMLogList,function(converter,sfmLogLayer,pfmLogLayer)
	for _,t in ipairs(sfmLogLayer:GetTimes()) do
		pfmLogLayer:GetTimesAttr():PushBack(t)
	end
	local type = sfmLogLayer:GetType()
	if(type == "DmeFloatLogLayer") then type = util.VAR_TYPE_FLOAT
	elseif(type == "DmeVector3LogLayer") then type = util.VAR_TYPE_VECTOR
	elseif(type == "DmeQuaternionLogLayer") then type = util.VAR_TYPE_QUATERNION
	elseif(type == "DmeIntLogLayer") then type = util.VAR_TYPE_INT32
	elseif(type == "DmeBoolLogLayer") then type = util.VAR_TYPE_BOOL
	else
		console.print_warning("Unsupported log layer type: ",type)
		return
	end

	pfmLogLayer:GetValuesAttr():SetValueType(type)
	for _,v in ipairs(sfmLogLayer:GetValues()) do
		pfmLogLayer:GetValuesAttr():PushBack(v)
	end
end)

sfm.register_element_type_conversion(sfm.Log,fudm.PFMLog,function(converter,sfmLog,pfmLog)
	for _,logLayer in ipairs(sfmLog:GetLayers()) do
		local pfmLogLayer = converter:ConvertNewElement(logLayer)
		pfmLog:AddLayer(pfmLogLayer)
	end
	for _,t in ipairs(sfmLog:GetBookmarks()) do
		pfmLog:GetBookmarks():PushBack(fudm.Float(t))
	end
	pfmLog:SetUseDefaultValue(sfmLog:GetUsedefaultvalue())

	local dmxLog = sfmLog:GetDMXElement()
	if(dmxLog ~= nil) then
		local defaultValue = dmxLog:GetAttr("defaultvalue")
		local type = defaultValue:GetType()
		if(type == dmx.Attribute.TYPE_INT) then pfmLog:SetDefaultValueAttr(fudm.Int(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_FLOAT) then pfmLog:SetDefaultValueAttr(fudm.Float(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_BOOL) then pfmLog:SetDefaultValueAttr(fudm.Bool(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_STRING) then pfmLog:SetDefaultValueAttr(fudm.String(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_COLOR) then pfmLog:SetDefaultValueAttr(fudm.Color(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_VECTOR3) then pfmLog:SetDefaultValueAttr(fudm.Vector3(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_VECTOR2) then pfmLog:SetDefaultValueAttr(fudm.Vector2(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_VECTOR4) then pfmLog:SetDefaultValueAttr(fudm.Vector4(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_ANGLE) then pfmLog:SetDefaultValueAttr(fudm.Angle(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_QUATERNION) then pfmLog:SetDefaultValueAttr(fudm.Quaternion(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_UINT8) then pfmLog:SetDefaultValueAttr(fudm.UInt8(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_UINT64) then pfmLog:SetDefaultValueAttr(fudm.UInt64(defaultValue:GetValue()))
		elseif(type == dmx.Attribute.TYPE_MATRIX) then pfmLog:SetDefaultValueAttr(fudm.Matrix(defaultValue:GetValue()))
		else
			local msg = "Unsupported default value type '" .. dmx.type_to_string(type) .. "' for log '" .. pfmLog:GetName() .. "'!"
			pfm.log(msg,pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_ERROR)
			error(msg)
		end
	else
		pfm.log("Log " .. tostring(sfmLog:GetName()) .. " does not have valid DMX element associated! Default value will be incorrect.",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
	end
end)

local function is_sfm_bone(el)
	for _,parent in ipairs(el:GetParents()) do
		local type = parent:GetType()
		if(type == "DmeGameModel" or (type == "DmeDag" and is_sfm_bone(parent))) then
			return true -- Element is a child of a DmeGameModel, which means it must be a bone
		end
	end
	return false
end

local function apply_override_parent(converter,sfmEl,pfmEl)
	if(sfmEl.GetOverrideParent == nil) then return end
	local overrideParent = sfmEl:GetOverrideParent()
	if(overrideParent == nil) then return end
	local pos = sfmEl:GetOverridePos() or false
	local rot = sfmEl:GetOverrideRot() or false
	local transform = pfmEl:GetTransform()
	transform:SetOverridePos(pos)
	transform:SetOverrideRot(rot)
	local pfmOverrideParent,isNewElement = converter:ConvertNewElement(overrideParent)
	-- Override parent is probably a game model, we'll just turn it into a reference.
	-- We'll turn it into a reference to the actor in post-processing.
	pfmOverrideParent = fudm.create_reference(pfmOverrideParent)
	transform:SetOverrideParentAttr(pfmOverrideParent)
end

sfm.register_element_type_conversion(sfm.Dag,function(converter,sfmDag)
	if(is_sfm_bone(sfmDag)) then return fudm.PFMBone end
	return fudm.PFMGroup
end,function(converter,sfmDag,pfmEl)
	if(pfmEl:GetType() == fudm.ELEMENT_TYPE_PFM_GROUP) then
		local pfmDag = pfmEl
		-- TODO: Unsure about sfm.ProjectConverter.TRANSFORM_TYPE_ALT, but has been confirmed to work with groups that contain particle
		-- systems! (e.g. session mtt_soldier_pyro_explosion_pos.dmx)
		pfmDag:SetTransformAttr(converter:ConvertNewElement(sfmDag:GetTransform(),sfm.ProjectConverter.TRANSFORM_TYPE_ALT))
		pfmDag:SetVisible(sfmDag:IsVisible())
		apply_override_parent(converter,sfmDag,pfmDag)
		for _,child in ipairs(sfmDag:GetChildren()) do
			local type = child:GetType()

			if(type == "DmeGameModel" or type == "DmeCamera" or type == "DmeProjectedLight" or type == "DmeGameParticleSystem") then
				local actor = converter:CreateActor(child,pfmDag)
				pfmDag:AddChild(fudm.create_reference(actor))

				apply_override_parent(converter,child,actor)
			else
				local pfmElement = converter:ConvertNewElement(child)
				pfmDag:AddChild(fudm.create_reference(pfmElement))

				apply_override_parent(converter,child,pfmElement)
			end
		end
		return
	end
	pfmEl:SetTransformAttr(converter:ConvertNewElement(sfmDag:GetTransform(),sfm.ProjectConverter.TRANSFORM_TYPE_NONE))
	apply_override_parent(converter,sfmDag,pfmEl)
	for _,child in ipairs(sfmDag:GetChildren()) do
		if(child:GetType() == "DmeDag") then
			pfmEl:GetChildBones():PushBack(converter:ConvertNewElement(child))
		else
			-- Note: Meet-the-Heavy has a case where a 'PFMParticleSystem' element is in the list of bones. TODO: What does that mean exactly?
			-- See also add_child_bones in sfm.GameModel conversion
			pfm.log("Expected bones of element '" .. pfmEl:GetName() .. "' to be of type 'DmeDag', but bone with type '" .. child:GetType() .. "' found! This is currently not supported!",pfm.LOG_CATEGORY_PFM_CONVERTER,pfm.LOG_SEVERITY_WARNING)
		end
	end
end)

sfm.register_element_type_conversion(sfm.MaterialOverlayFXClip,fudm.PFMOverlayClip,function(converter,sfmMat,pfmMat)
	pfmMat:SetTimeFrameAttr(converter:ConvertNewElement(sfmMat:GetTimeFrame()))
	local matName = asset.get_normalized_path(sfmMat:GetMaterial(),asset.TYPE_MATERIAL)
	pfmMat:SetMaterial(matName)
	pfmMat:SetLeft(sfmMat:GetLeft())
	pfmMat:SetTop(sfmMat:GetTop())
	pfmMat:SetWidth(sfmMat:GetWidth())
	pfmMat:SetHeight(sfmMat:GetHeight())
	pfmMat:SetFullscreen(sfmMat:IsFullscreen())
end)

sfm.register_element_type_conversion(sfm.ProjectedLight,fudm.PFMSpotLight,function(converter,sfmLight,pfmLight)
	pfmLight:SetColor(sfmLight:GetColor())
	pfmLight:SetIntensity(sfmLight:GetIntensity())
	pfmLight:SetIntensityType(ents.LightComponent.INTENSITY_TYPE_CANDELA)
	pfmLight:SetFalloffExponent(1.0)
	pfmLight:SetMaxDistance(sfmLight:GetMaxDistance())
	pfmLight:SetCastShadows(sfmLight:ShouldCastShadows())
	pfmLight:SetVolumetric(sfmLight:IsVolumetric())
	pfmLight:SetVolumetricIntensity(sfmLight:GetVolumetricIntensity() *0.05)

	local fov = math.max(sfmLight:GetHorizontalFOV(),sfmLight:GetVerticalFOV())
	pfmLight:SetOuterConeAngle(fov)
	pfmLight:SetInnerConeAngle(fov *0.7)
end)

sfm.register_element_type_conversion(sfm.GameParticleSystem,fudm.PFMParticleSystem,function(converter,sfmParticle,pfmParticle)
	pfmParticle:SetTimeScale(sfmParticle:GetSimulationTimeScale())
	pfmParticle:SetSimulating(sfmParticle:IsSimulating())
	pfmParticle:SetEmitting(sfmParticle:IsEmitting())
	local ptSystemName = sfmParticle:GetParticleSystemType()
	pfmParticle:SetParticleSystemName(ptSystemName)
	if(#ptSystemName == 0) then
		local ptSystemDef = sfmParticle:GetParticleSystemDefinition()
		local dmxEl = ptSystemDef:GetDMXElement()
		if(dmxEl ~= nil) then
			converter:AddParticleSystemDefinitionForConversion(pfmParticle,ptSystemDef)
		end
	end
	-- pfmParticle:SetDefinition(converter:ConvertNewElement())
	for _,cp in ipairs(sfmParticle:GetControlPoints()) do
		local pfmCp = converter:ConvertNewElement(cp)
		pfmParticle:GetControlPointsAttr():PushBack(pfmCp)
	end
end)

sfm.register_element_type_conversion(sfm.ParticleSystemDefinition,fudm.PFMParticleSystemDefinition,function(converter,sfmParticleDef,pfmParticleDef)
	pfmParticleDef:SetMaxParticles(sfmParticleDef:GetMaxParticles())
	pfmParticleDef:SetMaterial(sfmParticleDef:GetMaterial())
	pfmParticleDef:SetRadius(sfmParticleDef:GetRadius())
	pfmParticleDef:SetLifetime(sfmParticleDef:GetLifetime())
	pfmParticleDef:SetColor(sfmParticleDef:GetColor())
	pfmParticleDef:SetSortParticles(sfmParticleDef:ShouldSortParticles())

	for _,renderer in ipairs(sfmParticleDef:GetRenderers()) do
		local pfmRenderer = converter:ConvertNewElement(renderer)
		pfmParticleDef:GetRenderersAttr():PushBack(pfmRenderer)
	end

	for _,operator in ipairs(sfmParticleDef:GetOperators()) do
		local pfmOperator = converter:ConvertNewElement(operator)
		pfmParticleDef:GetOperatorsAttr():PushBack(pfmOperator)
	end

	for _,initializer in ipairs(sfmParticleDef:GetInitializers()) do
		local pfmInitializer = converter:ConvertNewElement(initializer)
		pfmParticleDef:GetInitializersAttr():PushBack(pfmInitializer)
	end
end)

sfm.register_element_type_conversion(sfm.ParticleSystemOperator,fudm.PFMParticleSystemOperator,function(converter,sfmParticleOp,pfmParticleOp)
	pfmParticleOp:SetOperatorName(sfmParticleOp:GetFunctionName())

	for name,attr in pairs(sfmParticleOp:GetDMXElement():GetAttributes()) do
		sfm.assign_generic_attribute(name,attr,pfmParticleOp)
	end
end)

sfm.register_element_type_conversion(sfm.ChannelClip,fudm.PFMChannelClip,function(converter,sfmChannelClip,pfmChannelClip)
	pfmChannelClip:SetTimeFrameAttr(converter:ConvertNewElement(sfmChannelClip:GetTimeFrame()))
	for _,channel in ipairs(sfmChannelClip:GetChannels()) do
		local fromElement = channel:GetFromElement()
		if(fromElement == nil or fromElement:GetType() ~= "DmeExpressionOperator") then
			pfmChannelClip:GetChannelsAttr():PushBack(converter:ConvertNewElement(channel))
		end
	end
end)

sfm.register_element_type_conversion(sfm.SoundClip,fudm.PFMAudioClip,function(converter,sfmSoundClip,pfmSoundClip)
	pfmSoundClip:SetSoundAttr(converter:ConvertNewElement(sfmSoundClip:GetSound()))
	pfmSoundClip:SetTimeFrameAttr(converter:ConvertNewElement(sfmSoundClip:GetTimeFrame()))
end)

sfm.register_element_type_conversion(sfm.Sound,fudm.PFMSound,function(converter,sfmSound,pfmSound)
	pfmSound:SetSoundName(sfmSound:GetSoundName())
	pfmSound:SetVolume(sfmSound:GetVolume())
	pfmSound:SetPitch(sfmSound:GetPitch() /100.0)
	pfmSound:SetOrigin(sfm.convert_source_position_to_pragma(sfmSound:GetOrigin()))
	pfmSound:SetDirection(sfm.convert_source_normal_to_pragma(sfmSound:GetDirection()))
end)

sfm.ProjectConverter.TRANSFORM_TYPE_NONE = -1
sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC = 0
sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL = 1
sfm.ProjectConverter.TRANSFORM_TYPE_BONE = 2
sfm.ProjectConverter.TRANSFORM_TYPE_ALT = 3
sfm.register_element_type_conversion(sfm.Transform,fudm.Transform,function(converter,sfmTransform,pfmTransform,type)
	pfmTransform:ChangeName(sfmTransform:GetName())
	type = type or sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC
	if(type == sfm.ProjectConverter.TRANSFORM_TYPE_GENERIC) then
		pfmTransform:SetPosition(sfm.convert_source_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_GLOBAL) then
		pfmTransform:SetPosition(sfm.convert_source_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_global_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_BONE) then
		pfmTransform:SetPosition(sfm.convert_source_anim_set_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_anim_set_rotation_to_pragma(sfmTransform:GetOrientation()))
	elseif(type == sfm.ProjectConverter.TRANSFORM_TYPE_ALT) then
		pfmTransform:SetPosition(sfm.convert_source_transform_position_to_pragma(sfmTransform:GetPosition()))
		pfmTransform:SetRotation(sfm.convert_source_transform_rotation_to_pragma2(sfmTransform:GetOrientation()))
	else
		pfmTransform:SetPosition(sfmTransform:GetPosition())
		pfmTransform:SetRotation(sfmTransform:GetOrientation())
	end

	local scale = sfmTransform:GetScale()
	pfmTransform:SetScale(Vector(scale,scale,scale))
end)

sfm.register_element_type_conversion(sfm.RigPointConstraintOperator,fudm.PFMRigPointConstraintOperator,function(converter,sfmOp,pfmOp)
	pfmOp:SetSlaveAttr(converter:ConvertNewElement(sfmOp:GetSlave()))
	for _,target in ipairs(sfmOp:GetTargets()) do
		pfmOp:GetTargetsAttr():PushBack(converter:ConvertNewElement(target))
	end
end)

sfm.register_element_type_conversion(sfm.RigOrientConstraintOperator,fudm.PFMRigRotationConstraintOperator,function(converter,sfmOp,pfmOp)
	pfmOp:SetSlaveAttr(converter:ConvertNewElement(sfmOp:GetSlave()))
	for _,target in ipairs(sfmOp:GetTargets()) do
		pfmOp:GetTargetsAttr():PushBack(converter:ConvertNewElement(target))
	end
end)

sfm.register_element_type_conversion(sfm.RigParentConstraintOperator,fudm.PFMRigParentConstraintOperator,function(converter,sfmOp,pfmOp)
	pfmOp:SetSlaveAttr(converter:ConvertNewElement(sfmOp:GetSlave()))
	for _,target in ipairs(sfmOp:GetTargets()) do
		pfmOp:GetTargetsAttr():PushBack(converter:ConvertNewElement(target))
	end
end)

sfm.register_element_type_conversion(sfm.ConstraintTarget,fudm.PFMConstraintTarget,function(converter,sfmTarget,pfmTarget)
	pfmTarget:SetTargetAttr(converter:ConvertNewElement(sfmTarget:GetTarget()))
	pfmTarget:SetTargetWeight(sfmTarget:GetTargetWeight())
	pfmTarget:SetOffset(sfm.convert_source_constraint_target_offset_to_pragma(sfmTarget:GetVecOffset()))
	pfmTarget:SetRotationOffset(sfm.convert_source_constraint_target_rotation_offset_to_pragma(sfmTarget:GetOOffset()))
end)

sfm.register_element_type_conversion(sfm.ConstraintSlave,fudm.PFMConstraintSlave,function(converter,sfmSlave,pfmSlave)
	pfmSlave:SetTargetAttr(converter:ConvertNewElement(sfmSlave:GetTarget()))
	-- TODO: Transform coordinate system
	pfmSlave:SetPosition(sfm.convert_source_anim_set_position_to_pragma(sfmSlave:GetPosition()))
	pfmSlave:SetRotation(sfm.convert_source_anim_set_rotation_to_pragma(sfmSlave:GetOrientation()))
end)

sfm.register_element_type_conversion(sfm.RigHandle,fudm.PFMRigHandle,function(converter,sfmHandle,pfmHandle)
	pfmHandle:SetTransformAttr(converter:ConvertNewElement(sfmHandle:GetTransform()))
end)
