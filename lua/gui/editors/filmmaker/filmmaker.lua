--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("../base_editor.lua")

util.register_class("gui.WIFilmmaker",gui.WIBaseEditor)

include("/gui/witabbedpanel.lua")
include("/gui/editors/wieditorwindow.lua")

locale.load("pfm_user_interface.txt")

include("windows")
include("video_recorder.lua")

include_component("pfm_camera")
include_component("pfm_sound_source")

gui.WIFilmmaker.CAMERA_MODE_PLAYBACK = 0
gui.WIFilmmaker.CAMERA_MODE_FLY = 1
gui.WIFilmmaker.CAMERA_MODE_WALK = 2
gui.WIFilmmaker.CAMERA_MODE_COUNT = 3

function gui.WIFilmmaker:__init()
	gui.WIBaseEditor.__init(self)
end
function gui.WIFilmmaker:OnRemove()
	gui.WIBaseEditor.OnRemove(self)
end
function gui.WIFilmmaker:OnThink()
	if(self.m_raytracingJob == nil) then return end
	local progress = self.m_raytracingJob:GetProgress()
	if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetProgress(progress) end
	if(self.m_raytracingJob:IsComplete() == false) then return end
	if(self.m_raytracingJob:IsSuccessful() == false) then
		self.m_raytracingJob = nil
		return
	end
	local imgBuffer = self.m_raytracingJob:GetResult()
	local img = vulkan.create_image(imgBuffer)
	local imgViewCreateInfo = vulkan.ImageViewCreateInfo()
	imgViewCreateInfo.swizzleAlpha = vulkan.COMPONENT_SWIZZLE_ONE -- We'll ignore the alpha value
	local tex = vulkan.create_texture(img,vulkan.TextureCreateInfo(),imgViewCreateInfo,vulkan.SamplerCreateInfo())
	if(self.m_renderResultWindow ~= nil) then self.m_renderResultWindow:SetTexture(tex) end
	if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetVisible(false) end

	self.m_raytracingJob = nil
	if(self:IsRecording() == false) then return end
	-- Write the rendered frame and kick off the next one
	self.m_videoRecorder:WriteFrame(imgBuffer)

	local gameView = self:GetGameView()
	local projectC = util.is_valid(gameView) and gameView:GetComponent(ents.COMPONENT_PFM_PROJECT) or nil
	if(projectC ~= nil) then
		projectC:SetOffset(projectC:GetOffset() +self.m_videoRecorder:GetFrameDeltaTime())
		self:CaptureRaytracedImage()
	end
end
function gui.WIFilmmaker:OnInitialize()
	gui.WIBaseEditor.OnInitialize(self)
	
	if(util.is_valid(self.m_pMain)) then self.m_pMain:SetVisible(false) end
	self:SetSize(1280,1024)
	local pMenuBar = self:GetMenuBar()
	pMenuBar:AddItem(locale.get_text("file"),function(pContext)
		pContext:AddItem(locale.get_text("open") .. "...",function(pItem)
			if(util.is_valid(self.m_openDialogue)) then self.m_openDialogue:Remove() end
			self.m_openDialogue = gui.create_file_open_dialog(function(pDialog,fileName)
				self:LoadProject(fileName)
			end)
			self.m_openDialogue:SetRootPath("sfm_sessions")
			self.m_openDialogue:SetExtensions({"dmx"})
			self.m_openDialogue:Update()
		end)
		pContext:AddItem(locale.get_text("import") .. "...",function(pItem)
			if(util.is_valid(self) == false) then return end
			
		end)
		pContext:AddItem(locale.get_text("save") .. "...",function(pItem)
			if(util.is_valid(self) == false) then return end
			
		end)
		pContext:AddItem(locale.get_text("exit"),function(pItem)
			if(util.is_valid(self) == false) then return end
			tool.close_filmmaker()
		end)
		pContext:Update()
	end)
	pMenuBar:AddItem(locale.get_text("edit"),function(pContext)

	end)
	pMenuBar:AddItem(locale.get_text("windows"),function(pContext)

	end)
	pMenuBar:AddItem(locale.get_text("view"),function(pContext)

	end)
	pMenuBar:AddItem(locale.get_text("help"),function(pContext)

	end)
	pMenuBar:Update()

	local framePlaybackControls = gui.create("WIFrame",self)
	framePlaybackControls:SetCloseButtonEnabled(false)
	local playbackControls = gui.create("PlaybackControls",framePlaybackControls)
	playbackControls:SetX(10)
	playbackControls:SetY(24)
	playbackControls:SetWidth(512)
	playbackControls:AddCallback("OnProgressChanged",function(playbackControls,progress,timeOffset)
		if(util.is_valid(self.m_gameView)) then
			local projectC = self.m_gameView:GetComponent(ents.COMPONENT_PFM_PROJECT)
			if(projectC ~= nil) then projectC:SetOffset(timeOffset) end
		end
	end)
	playbackControls:AddCallback("OnStateChanged",function(playbackControls,oldState,newState)
		ents.PFMSoundSource.set_audio_enabled(newState == gui.PlaybackControls.STATE_PLAYING)
	end)
	self.m_playbackControls = playbackControls

	local buttonScreenshot = gui.create("WITexturedRect",framePlaybackControls)
	buttonScreenshot:SetMaterial("gui/pfm/photo_camera")
	buttonScreenshot:SetSize(20,20)
	buttonScreenshot:SetTop(playbackControls:GetTop() +1)
	buttonScreenshot:SetLeft(playbackControls:GetRight() +10)
	buttonScreenshot:SetMouseInputEnabled(true)
	buttonScreenshot:AddCallback("OnMousePressed",function()
		self:CaptureRaytracedImage()
	end)

	local buttonRecord = gui.create("WITexturedRect",framePlaybackControls)
	buttonRecord:SetMaterial("gui/pfm/video_camera")
	buttonRecord:SetSize(20,20)
	buttonRecord:SetTop(playbackControls:GetTop() +1)
	buttonRecord:SetLeft(buttonScreenshot:GetRight() +10)
	buttonRecord:SetMouseInputEnabled(true)
	buttonRecord:AddCallback("OnMousePressed",function()
		if(self:IsRecording() == false) then
			self:StartRecording("pfmtest.avi")
		else
			self:StopRecording()
		end
	end)

	local wFrame = buttonRecord:GetRight() +10
	local hFrame = playbackControls:GetBottom() +20
	framePlaybackControls:SetMaxHeight(hFrame)
	framePlaybackControls:SetMinHeight(hFrame)
	framePlaybackControls:SetMinWidth(128)
	framePlaybackControls:SetMaxWidth(1024)
	framePlaybackControls:SetWidth(wFrame)
	framePlaybackControls:SetHeight(hFrame)
	framePlaybackControls:SetPos(128,900)

	buttonScreenshot:SetAnchor(1,0.5,1,0.5)
	buttonRecord:SetAnchor(1,0.5,1,0.5)
	playbackControls:SetAnchor(0,0,1,1)

	local progressBar = playbackControls:GetProgressBar()
	local raytracingProgressBar = gui.create("WIProgressBar",framePlaybackControls)
	raytracingProgressBar:SetSize(progressBar:GetWidth(),10)
	raytracingProgressBar:SetLeft(playbackControls:GetLeft() +progressBar:GetLeft())
	raytracingProgressBar:SetTop(playbackControls:GetBottom())
	raytracingProgressBar:SetColor(Color.Lime)
	raytracingProgressBar:SetVisible(false)
	raytracingProgressBar:SetAnchor(0,0,1,1)
	self.m_raytracingProgressBar = raytracingProgressBar
	
	-- This controls the behavior that allows controlling the camera while holding the right mouse button down
	self.m_cbClickMouseInput = input.add_callback("OnMouseInput",function(mouseButton,state,mods)
		if(mouseButton ~= input.MOUSE_BUTTON_LEFT and mouseButton ~= input.MOUSE_BUTTON_RIGHT) then return util.EVENT_REPLY_UNHANDLED end
		if(state ~= input.STATE_PRESS and state ~= input.STATE_RELEASE) then return util.EVENT_REPLY_UNHANDLED end

		local pFrame = self
		if(self.m_inCameraControlMode and mouseButton == input.MOUSE_BUTTON_RIGHT and state == input.STATE_RELEASE and pFrame:IsValid() and pFrame:HasFocus() == false) then
			pFrame:TrapFocus(true)
			pFrame:RequestFocus()
			input.set_cursor_pos(self.m_oldCursorPos)
			self.m_inCameraControlMode = false
			return util.EVENT_REPLY_HANDLED
		end

		local el = gui.get_element_under_cursor()
		if(util.is_valid(el) and (el == self or el == gui.get_base_element())) then
			local action
			if(mouseButton == input.MOUSE_BUTTON_LEFT) then action = input.ACTION_ATTACK
			else action = input.ACTION_ATTACK2 end

			local pFrame = self
			if(mouseButton == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
				self.m_oldCursorPos = input.get_cursor_pos()
				input.center_cursor()
				pFrame:TrapFocus(false)
				pFrame:KillFocus()
				self.m_inCameraControlMode = true
			end
			return util.EVENT_REPLY_HANDLED
		end
		return util.EVENT_REPLY_UNHANDLED
	end)

	self.m_previewWindow = gui.PFMRenderPreviewWindow(self)
	self.m_renderResultWindow = gui.PFMRenderResultWindow(self)
	self.m_previewWindow:GetFrame():SetY(24)
	self.m_renderResultWindow:GetFrame():SetY(self.m_previewWindow:GetFrame():GetBottom() +10)
	self.m_videoRecorder = pfm.VideoRecorder()

	local btCam = gui.create_button("Toggle Camera",self,100,20)
	btCam:AddCallback("OnPressed",function()
		self:SetCameraMode((self.m_cameraMode +1) %gui.WIFilmmaker.CAMERA_MODE_COUNT)
	end)

	self:SetCameraMode(gui.WIFilmmaker.CAMERA_MODE_PLAYBACK)
	self:CreateNewProject()
end
function gui.WIFilmmaker:OnRemove()
	self:CloseProject()
	if(util.is_valid(self.m_cbClickMouseInput)) then self.m_cbClickMouseInput:Remove() end
	if(util.is_valid(self.m_openDialogue)) then self.m_openDialogue:Remove() end
	if(self.m_previewWindow ~= nil) then self.m_previewWindow:Remove() end
	if(self.m_renderResultWindow ~= nil) then self.m_renderResultWindow:Remove() end
end
function gui.WIFilmmaker:SetCameraMode(camMode)
	pfm.log("Changing camera mode to " .. ((camMode == gui.WIFilmmaker.CAMERA_MODE_PLAYBACK and "playback") or (camMode == gui.WIFilmmaker.CAMERA_MODE_FLY and "fly") or "walk"))
	self.m_cameraMode = camMode

	ents.PFMCamera.set_camera_enabled(camMode == gui.WIFilmmaker.CAMERA_MODE_PLAYBACK)

	--[[local camGame = game.get_primary_camera()
	local toggleC = (camGame ~= nil) and camGame:GetEntity():GetComponent(ents.COMPONENT_TOGGLE) or nil
	if(camMode == gui.WIFilmmaker.CAMERA_MODE_FLY) then
		if(toggleC ~= nil) then toggleC:TurnOn() end
	elseif(camMode == gui.WIFilmmaker.CAMERA_MODE_WALK) then
		if(toggleC ~= nil) then toggleC:TurnOn() end
	else
		if(toggleC ~= nil) then toggleC:TurnOff() end
	end]]

	-- We need to notify the server to change the player's movement mode (i.e. noclip/walk)
	local packet = net.Packet()
	packet:WriteUInt8(camMode)
	net.send(net.PROTOCOL_SLOW_RELIABLE,"sv_pfm_camera_mode",packet)
end
function gui.WIFilmmaker:CaptureRaytracedImage()
	if(self.m_raytracingJob ~= nil) then self.m_raytracingJob:Cancel() end
	local job = util.capture_raytraced_screenshot(1024,1024,64)--2048,2048,1024)
	job:Start()
	self.m_raytracingJob = job

	if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetVisible(true) end
end
function gui.WIFilmmaker:StartRecording(fileName)
	local success = self.m_videoRecorder:StartRecording(fileName)
	if(success == false) then return false end
	self:CaptureRaytracedImage()
	return success
end
function gui.WIFilmmaker:IsRecording() return self.m_videoRecorder:IsRecording() end
function gui.WIFilmmaker:StopRecording()
	self.m_videoRecorder:StopRecording()
end
function gui.WIFilmmaker:CloseProject()
	pfm.log("Closing project...",pfm.LOG_CATEGORY_PFM)
	if(util.is_valid(self.m_gameView)) then self.m_gameView:Remove() end
end
function gui.WIFilmmaker:GetGameView() return self.m_gameView end
function gui.WIFilmmaker:CreateNewProject()
	self:CloseProject()
	pfm.log("Creating new project...",pfm.LOG_CATEGORY_PFM)

	local entScene = ents.create("pfm_project")
	if(util.is_valid(entScene) == false) then
		pfm.log("Unable to initialize PFM project: Count not create 'pfm_project' entity!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_ERROR)
		return false
	end
	local projectC = entScene:GetComponent(ents.COMPONENT_PFM_PROJECT)
	projectC:SetProjectData(pfm.create_project())
	entScene:Spawn()
	self.m_gameView = entScene
	projectC:Start()
	if(util.is_valid(self.m_playbackControls)) then self.m_playbackControls:SetDuration(0.0) end
	return entScene
end
function gui.WIFilmmaker:LoadProject(projectFilePath)
	self:CloseProject()
	pfm.log("Converting SFM project '" .. projectFilePath .. "' to PFM...",pfm.LOG_CATEGORY_SFM)
	local pfmScene = sfm.ProjectConverter.convert_project(projectFilePath)
	if(pfmScene == false) then
		pfm.log("Unable to convert SFM project '" .. projectFilePath .. "'!",pfm.LOG_CATEGORY_SFM,pfm.LOG_SEVERITY_WARNING)
		return false
	end

	pfm.log("Initializing PFM project...",pfm.LOG_CATEGORY_PFM)
	local entScene = ents.create("pfm_project")
	if(util.is_valid(entScene) == false) then
		pfm.log("Unable to initialize PFM project: Count not create 'pfm_project' entity!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_ERROR)
		return false
	end
	local projectC = entScene:GetComponent(ents.COMPONENT_PFM_PROJECT)
	projectC:SetProjectData(pfmScene)
	entScene:Spawn()
	self.m_gameView = entScene
	projectC:Start()
	if(util.is_valid(self.m_playbackControls)) then
		local timeFrame = projectC:GetTimeFrame()
		self.m_playbackControls:SetDuration(timeFrame:GetDuration())
		self.m_playbackControls:SetOffset(0.0)
	end
	return entScene
end
gui.register("WIFilmmaker",gui.WIFilmmaker)
