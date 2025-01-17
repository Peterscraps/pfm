--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/gui/wiviewport.lua")
include("/gui/hbox.lua")
include("/gui/aspectratio.lua")
include("/gui/pfm/button.lua")
include("/gui/pfm/playbutton.lua")
include("/gui/pfm/base_viewport.lua")
include("/gui/pfm/cursor_tracker.lua")
include("/gui/draganddrop.lua")
include("/gui/playbackcontrols.lua")
include("/gui/raytracedviewport.lua")
include("/pfm/fonts.lua")
include("/pfm/undoredo.lua")

include_component("click")
include_component("util_transform")
include_component("pfm_bone")

util.register_class("gui.PFMViewport",gui.PFMBaseViewport)

include("transform_gizmo.lua")
include("camera.lua")
include("selection.lua")
include("ui.lua")

function gui.PFMViewport:OnInitialize()
	self.m_vrControllers = {}
	self.m_manipulatorMode = gui.PFMViewport.MANIPULATOR_MODE_SELECT

	gui.PFMBaseViewport.OnInitialize(self)

	self.m_titleBar:SetHeight(37)

	self.m_gameplayEnabled = true
	self.m_cameraView = gui.PFMViewport.CAMERA_VIEW_SCENE
	self.m_aspectRatioWrapper:AddCallback("OnAspectRatioChanged",function(el,aspectRatio)
		if(util.is_valid(self.m_viewport)) then
			local scene = self.m_viewport:GetScene()
			if(scene ~= nil) then
				local cam = scene:GetActiveCamera()
				if(cam ~= nil) then
					cam:SetAspectRatio(aspectRatio)
					cam:UpdateMatrices()
				end
			end
		end
		--[[local maxResolution = engine.get_window_resolution()
		local w,h = util.clamp_resolution_to_aspect_ratio(maxResolution.x,maxResolution.y,aspectRatio)
		self.m_viewport:SetupScene(maxResolution.x,maxResolution.y)]]
		--self:Update()
	end)

	local function create_text_element(font,pos,color)
		local textColor = Color(182,182,182)
		local el = gui.create("WIText",self.m_titleBar)
		el:SetFont(font)
		el:SetColor(textColor)
		el:SetPos(pos)
		return el
	end
	local textColor = Color(182,182,182)
	self.m_timeGlobal = create_text_element("pfm_large",Vector2(20,15),textColor)
	self.m_timeGlobal:SetText(util.get_pretty_time(0.0))
	self.m_timeGlobal:SizeToContents()

	self.m_timeLocal = create_text_element("pfm_large",Vector2(0,15),textColor)
	self.m_timeLocal:SetText(util.get_pretty_time(0.0))
	self.m_timeLocal:SizeToContents()
	self.m_timeLocal:SetAnchor(1,0,1,0)

	textColor = Color(152,152,152)
	self.m_filmClipParent = create_text_element("pfm_medium",Vector2(0,3),textColor)
	self.m_filmClipParent:CenterToParentX()
	self.m_filmClipParent:SetAnchor(0.5,0,0.5,0)

	self.m_filmClip = create_text_element("pfm_medium",Vector2(0,16),textColor)
	self.m_filmClip:CenterToParentX()
	self.m_filmClip:SetAnchor(0.5,0,0.5,0)

	self:SwitchToGameplay(false)
	time.create_simple_timer(0.0,function()
		if(self:IsValid()) then self:SwitchToWorkCamera() end
	end)
end
function gui.PFMViewport:ShowAnimationOutline(show)
	if(show == false) then
		util.remove(self.m_animOutline)
		return
	end
	if(util.is_valid(self.m_animOutline)) then return end
	local vpInner = self:GetViewport()
	local el = gui.create("WIOutlinedRect",vpInner,0,0,vpInner:GetWidth(),vpInner:GetHeight(),0,0,1,1)
	el:SetColor(pfm.get_color_scheme_color("red"))
	el:SetZPos(10)
	self.m_animOutline = el
end
function gui.PFMViewport:InitializeCustomScene()
	local sceneCreateInfo = ents.SceneComponent.CreateInfo()
	sceneCreateInfo.sampleCount = prosper.SAMPLE_COUNT_1_BIT
	local gameScene = game.get_scene()
	local gameRenderer = gameScene:GetRenderer()
	local scene = ents.create_scene(sceneCreateInfo,gameScene)
	self.m_scene = scene

	local entRenderer = ents.create("rasterization_renderer")
	local renderer = entRenderer:GetComponent(ents.COMPONENT_RENDERER)
	self.m_renderer = renderer
	local rasterizer = entRenderer:GetComponent(ents.COMPONENT_RASTERIZATION_RENDERER)
	rasterizer:SetSSAOEnabled(true)
	renderer:InitializeRenderTarget(scene,gameRenderer:GetWidth(),gameRenderer:GetHeight())
	scene:SetRenderer(renderer)
	scene:SetWorldEnvironment(gameScene:GetWorldEnvironment())

	local gameCam = gameScene:GetActiveCamera()
	local cam = ents.create_camera(gameCam:GetAspectRatio(),gameCam:GetFOV(),gameCam:GetNearZ(),gameCam:GetFarZ())
	self.m_camera = cam
	scene:SetActiveCamera(cam)

	self.m_viewport:SetScene(scene,nil,function() return game.is_default_game_render_enabled() end)
end
function gui.PFMViewport:SetRtViewportRenderer(renderer)
	local enabled = (renderer ~= nil)
	console.run("cl_max_fps",enabled and "24" or tostring(console.get_convar_int("pfm_max_fps"))) -- Clamp max fps to make more resources available for the renderer
	util.remove(self.m_rtViewport)
	tool.get_filmmaker():SetOverlaySceneEnabled(false)
	if(enabled ~= true) then return end
	local rtViewport = gui.create("WIRealtimeRaytracedViewport",self.m_vpContainer,0,0,self.m_vpContainer:GetWidth(),self.m_vpContainer:GetHeight(),0,0,1,1)
	rtViewport:SetRenderer(renderer)
	local scene = self.m_viewport:GetScene()
	if(util.is_valid(scene)) then rtViewport:SetGameScene(scene) end
	self.m_rtViewport = rtViewport
	tool.get_filmmaker():SetOverlaySceneEnabled(true)

	self:UpdateRenderSettings()
end
function gui.PFMViewport:GetRealtimeRaytracedViewport() return self.m_rtViewport end
function gui.PFMViewport:StopLiveRaytracing()
	self.m_ctrlRt:SelectOption(0)
end
function gui.PFMViewport:UpdateRenderSettings()
	local pfm = tool.get_filmmaker()
	local renderTab = pfm:GetRenderTab()
	if(util.is_valid(self.m_rtViewport) == false or util.is_valid(renderTab) == false) then return end
	self.m_rtViewport:SetRenderSettings(renderTab:GetRenderSettings())
	self.m_rtViewport:Refresh(true)
end
function gui.PFMViewport:OnViewportMouseEvent(el,mouseButton,state,mods)
	if(mouseButton == input.MOUSE_BUTTON_LEFT and self:GetManipulatorMode() == gui.PFMViewport.MANIPULATOR_MODE_SELECT) then
		if(state == input.STATE_PRESS) then
			self.m_leftMouseInput = true
			self.m_cursorTracker = gui.CursorTracker()
			self:EnableThinking()
			return util.EVENT_REPLY_HANDLED
		end
		local selectionApplied = self:ApplySelection()

		self.m_leftMouseInput = nil
		self.m_cursorTracker = nil

		if(selectionApplied == false) then
			local handled,entActor,hitPos,startPos,hitData = ents.ClickComponent.inject_click_input(input.ACTION_ATTACK,true)
			if(handled == util.EVENT_REPLY_UNHANDLED and util.is_valid(entActor)) then
				local actorC = entActor:GetComponent(ents.COMPONENT_PFM_ACTOR)
				local actor = (actorC ~= nil) and actorC:GetActorData() or nil
				if(actor) then
					local filmmaker = tool.get_filmmaker()
					if(input.is_alt_key_down()) then
						filmmaker:DeselectActor(actor)
					else
						local bone,hitPosBone = self:FindBoneUnderCursor(entActor)
						local deselectCurrent = not input.is_ctrl_key_down()
						self:SelectActor(entActor,bone,deselectCurrent)
					end
				end
			end
		end
		return util.EVENT_REPLY_HANDLED
	end

	if(mouseButton ~= input.MOUSE_BUTTON_LEFT and mouseButton ~= input.MOUSE_BUTTON_RIGHT) then return util.EVENT_REPLY_UNHANDLED end
	if(state ~= input.STATE_PRESS and state ~= input.STATE_RELEASE) then return util.EVENT_REPLY_UNHANDLED end

	local function findActor(pressed,filter)
		if(pressed == nil) then pressed = state == input.STATE_PRESS end
		--[[if(self.m_manipulatorMode ~= gui.PFMViewport.MANIPULATOR_MODE_SELECT) then
			filter = function(ent,mdlC)
				return not ent:HasComponent(ents.COMPONENT_PFM_ACTOR)
			end
		end]]
		return ents.ClickComponent.inject_click_input(input.ACTION_ATTACK,pressed,filter)
	end

	--[[if(mouseButton == input.MOUSE_BUTTON_RIGHT) then
		self.m_viewport:RequestFocus()
		if(state == input.STATE_PRESS) then
			self.m_cursorTracker = gui.CursorTracker()
			self:EnableThinking()
		elseif(state == input.STATE_RELEASE) then

		end
		return util.EVENT_REPLY_HANDLED
	end]]

	local filmmaker = tool.get_filmmaker()
	if(self.m_inCameraControlMode and mouseButton == input.MOUSE_BUTTON_RIGHT and state == input.STATE_RELEASE and filmmaker:IsValid()) then
		self:SetGameplayMode(false)
		return util.EVENT_REPLY_HANDLED
	end

	local window = self:GetRootWindow()
	local el = gui.get_element_under_cursor(window)
	if(util.is_valid(el) and (el == self or el:IsDescendantOf(self))) then
		if(mouseButton == input.MOUSE_BUTTON_RIGHT) then
			if(state == input.STATE_PRESS) then
				self.m_cursorTracker = gui.CursorTracker()
				self:EnableThinking()
				return util.EVENT_REPLY_HANDLED
			else
				if(self.m_cursorTracker ~= nil) then
					self.m_cursorTracker = nil
					self:DisableThinking()

					local handled,entActor,hitPos,startPos,hitData = findActor(true)
					if(handled == util.EVENT_REPLY_UNHANDLED and util.is_valid(entActor)) then
						local pContext = gui.open_context_menu()
						if(util.is_valid(pContext) == false) then return end
						pContext:SetPos(input.get_cursor_pos())

						local hitMaterial
						local idx = hitData.mesh:GetSkinTextureIndex()
						local mdl = entActor:GetModel()
						if(mdl ~= nil) then
							local mat = mdl:GetMaterial(idx)
							if(mat ~= nil) then
								hitMaterial = mat
							end
						end

						local actorC = entActor:GetComponent(ents.COMPONENT_PFM_ACTOR)
						local actor = (actorC ~= nil) and actorC:GetActorData() or nil
						if(actor ~= nil) then pfm.populate_actor_context_menu(pContext,actor,nil,hitMaterial) end

						if(hitData.mesh ~= nil and hitData.primitiveIndex ~= nil) then
							pContext:AddItem(locale.get_text("pfm_copy_hit_position"),function()
								util.set_clipboard_string(tostring(hitPos))
							end)
						end

						pContext:Update()
					end
				end
			end
		elseif(mouseButton == input.MOUSE_BUTTON_LEFT) then
			if(util.is_valid(self.m_rtMoverActor)) then
				self.m_rtMoverActor:RemoveComponent("pfm_rt_mover")
				tool.get_filmmaker():TagRenderSceneAsDirty()
				local actorC = util.is_valid(self.m_rtMoverActor) and self.m_rtMoverActor:GetComponent(ents.COMPONENT_PFM_ACTOR) or nil
				if(actorC ~= nil) then
					local curPos = actorC:GetMemberValue("position") 
					local newPos = self.m_rtMoverActor:GetPos()
					local function apply_pos(pos)
						tool.get_filmmaker():SetActorTransformProperty(actorC,"position",pos)
						if(util.is_valid(self.m_rtMoverActor)) then self:OnActorTransformChanged(self.m_rtMoverActor) end
					end
					pfm.undoredo.push("pfm_undoredo_transform",function() apply_pos(newPos) end,function() apply_pos(curPos) end)()
					apply_pos(newPos)
				end
				self.m_rtMoverActor = nil
				if(state == input.STATE_RELEASE) then return util.EVENT_REPLY_HANDLED end
			end

			local handled,entActor = findActor()
			if(self:IsMoveManipulatorMode(self:GetManipulatorMode()) and (entActor == nil or entActor:HasComponent(ents.COMPONENT_UTIL_TRANSFORM_ARROW) == false)) then
				local pm = tool.get_filmmaker()
				local selectionManager = pm:GetSelectionManager()
				local objs = selectionManager:GetSelectedObjects()
				local obj = pairs(objs)(objs)
				if(util.is_valid(obj)) then
					handled = util.EVENT_REPLY_UNHANDLED
					entActor = obj
				end
			end

			if(handled == util.EVENT_REPLY_UNHANDLED and util.is_valid(entActor) and state == input.STATE_PRESS) then
				local actorC = entActor:GetComponent(ents.COMPONENT_PFM_ACTOR)
				local actor = (actorC ~= nil) and actorC:GetActorData() or nil
				if(actor) then
					local bone,hitPosBone = self:FindBoneUnderCursor(entActor)
					if(bone ~= nil) then
						self:SelectActor(entActor,bone,true)
						filmmaker:GetActorEditor():UpdateSelectedEntities()

						local transformC = util.is_valid(self.m_entTransform) and self.m_entTransform:GetComponent(ents.COMPONENT_UTIL_TRANSFORM) or nil
						if(transformC ~= nil) then transformC:StartTransform("xyz",ents.UtilTransformArrowComponent.AXIS_XYZ,ents.UtilTransformArrowComponent.TYPE_TRANSLATION,hitPosBone) end
					end
					--[[if(self:IsMoveManipulatorMode(self:GetManipulatorMode())) then
						if(state == input.STATE_PRESS) then
							self.m_rtMoverActor = entActor
							entActor:AddComponent("pfm_rt_mover")
							tool.get_filmmaker():TagRenderSceneAsDirty(true)
						end
					else
						if(input.is_alt_key_down()) then
							filmmaker:DeselectActor(actor)
						else
							local deselectCurrent = not input.is_ctrl_key_down()
							filmmaker:SelectActor(actor,deselectCurrent)
						end
					end]]
				end
			end
		end
		return util.EVENT_REPLY_HANDLED
	end
	return util.EVENT_REPLY_UNHANDLED
end
function gui.PFMViewport:OnRemove()
	util.remove(self.m_entTransform)
	if(util.is_valid(self.m_scene)) then self.m_scene:GetEntity():Remove() end
	if(util.is_valid(self.m_renderer)) then self.m_renderer:GetEntity():Remove() end
	if(util.is_valid(self.m_camera)) then self.m_camera:GetEntity():Remove() end
	for _,ent in ipairs(self.m_vrControllers) do
		if(ent:IsValid()) then ent:Remove() end
	end
end
function gui.PFMViewport:SetGlobalTime(time)
	if(util.is_valid(self.m_timeGlobal)) then
		self.m_timeGlobal:SetText(util.get_pretty_time(time))
		self.m_timeGlobal:SizeToContents()
	end
end
function gui.PFMViewport:SetLocalTime(time)
	if(util.is_valid(self.m_timeLocal)) then
		self.m_timeLocal:SetText(util.get_pretty_time(time))
		self.m_timeLocal:SizeToContents()
	end
end
function gui.PFMViewport:SetFilmClipName(name)
	if(util.is_valid(self.m_filmClip)) then
		if(name == self.m_filmClip:GetText()) then return end
		self.m_filmClip:SetText(name)
		self.m_filmClip:SizeToContents()

		self:UpdateFilmLabelPositions()
	end
end
function gui.PFMViewport:SetFilmClipParentName(name)
	if(util.is_valid(self.m_filmClipParent)) then
		if(name == self.m_filmClipParent:GetText()) then return end
		self.m_filmClipParent:SetText(name)
		self.m_filmClipParent:SizeToContents()

		self:UpdateFilmLabelPositions()
	end
end
function gui.PFMViewport:UpdateFilmLabelPositions()
	if(util.is_valid(self.m_filmClipParent)) then
		self.m_filmClipParent:SetX(self.m_titleBar:GetWidth() *0.5 -self.m_filmClipParent:GetWidth() *0.5)
	end
	if(util.is_valid(self.m_filmClip)) then
		self.m_filmClip:SetX(self.m_titleBar:GetWidth() *0.5 -self.m_filmClip:GetWidth() *0.5)
	end
end
function gui.PFMViewport:MarkActorAsDirty(ent)
	local rt = self:GetRealtimeRaytracedViewport() or nil
	if(util.is_valid(rt)) then
		rt:MarkActorAsDirty(ent)
	end
end
function gui.PFMViewport:ApplyPoseToKeyframeAnimation(actorData,origPose,newPose)
	local offsetPose = math.Transform()
	if(newPose.position ~= nil) then offsetPose:SetOrigin(newPose.position -origPose:GetOrigin()) end
	if(newPose.rotation ~= nil) then offsetPose:SetRotation(origPose:GetInverse() *newPose.rotation) end

	local rotOrigin = (newPose.position ~= nil) and newPose.position or origPose:GetOrigin()

	local pm = pfm.get_project_manager()
	local session = (pm ~= nil) and pm:GetSession() or nil
	local filmClip = (session ~= nil) and session:FindClipAtTimeOffset(pm:GetTimeOffset()) or nil

	local paths = {"ec/pfm_actor/position","ec/pfm_actor/rotation"}
	local animPath = 2
	for i,path in ipairs(paths) do
		local isRotation = (i == animPath)

		local track = filmClip:FindAnimationChannelTrack()
		local animClip = (track ~= nil) and track:FindActorAnimationClip(actorData) or nil
		local channel = (animClip ~= nil) and animClip:FindChannel(path) or nil
		if(channel ~= nil) then
			local valueType = channel:GetValueArrayValueType()
			if(valueType == udm.TYPE_VECTOR3) then
				local values = channel:GetValues()
				for i,v in ipairs(values) do
					v = offsetPose:GetOrigin() +v
					v:RotateAround(rotOrigin,offsetPose:GetRotation())
					channel:SetValue(i -1,v)
				end
			elseif(valueType == udm.TYPE_QUATERNION) then
				local values = channel:GetValues()
				for i,v in ipairs(values) do
					v = v *offsetPose:GetRotation()
					channel:SetValue(i -1,v)
				end
			elseif(valueType == udm.TYPE_EULER_ANGLES) then
				local values = channel:GetValues()
				for i,v in ipairs(values) do
					v = v:ToQuaternion() *offsetPose:GetRotation()
					channel:SetValue(i -1,v:ToEulerAngles())
				end
			end
		end

		-- Update keyframes
		local editorData = (animClip ~= nil) and animClip:GetEditorData() or nil
		local editorChannel = (editorData ~= nil) and editorData:FindChannel(path) or nil
		local graphCurve = (editorChannel ~= nil) and editorChannel:GetGraphCurve() or nil
		if(graphCurve ~= nil) then
			local k0 = graphCurve:GetKey(0)
			local k1 = graphCurve:GetKey(1)
			local k2 = graphCurve:GetKey(2)
			if(k0 ~= nil and k1 ~= nil and k2 ~= nil and k0:GetValueCount() == k1:GetValueCount() and k0:GetValueCount() == k2:GetValueCount()) then
				local n = k0:GetValueCount()
				local applyToKeyframe = true
				for i=0,n -1 do
					local t0 = k0:GetTime(i)
					local t1 = k1:GetTime(i)
					local t2 = k2:GetTime(i)
					if(math.abs(t1 -t0) > 0.001 or math.abs(t2 -t0) > 0.001) then
						applyToKeyframe = false
						break
					end
				end
				if(applyToKeyframe == false) then
					pfm.create_popup_message(locale.get_text("pfm_popup_failed_to_transform_keyframe",{path}))
				else
					if(isRotation) then
						for i=0,n -1 do
							local v = EulerAngles(k0:GetValue(i),k1:GetValue(i),k2:GetValue(i)):ToQuaternion()
							v = offsetPose:GetRotation() *v
							v = v:ToEulerAngles()
							k0:SetValue(i,v:Get(0))
							k1:SetValue(i,v:Get(1))
							k2:SetValue(i,v:Get(2))
						end
					else
						for i=0,n -1 do
							local v = Vector(k0:GetValue(i),k1:GetValue(i),k2:GetValue(i))
							v = offsetPose:GetOrigin() +v
							v:RotateAround(rotOrigin,offsetPose:GetRotation())
							k0:SetValue(i,v:Get(0))
							k1:SetValue(i,v:Get(1))
							k2:SetValue(i,v:Get(2))
						end
					end
				end
			end
		end

		local pm = pfm.get_project_manager()
		local animManager = pm:GetAnimationManager()
		if(animClip ~= nil) then animClip:SetPanimaAnimationDirty() end
		animManager:SetAnimationsDirty()
		pfm.tag_render_scene_as_dirty()
	end
end
function gui.PFMViewport:OnThink()
	if(self.m_cursorTracker ~= nil) then
		self.m_cursorTracker:Update()
		if(not self.m_cursorTracker:HasExceededMoveThreshold(2)) then return end

		if(self.m_leftMouseInput) then
			if(util.is_valid(self.m_selectionRect) == false) then
				self.m_selectionRect = gui.create("WISelectionRect",self.m_viewport)
				self.m_selectionRect:SetPos(self.m_viewport:GetCursorPos())
			end
			return
		end

		self.m_cursorTracker = nil
		self:DisableThinking()

		local targetPose
		if(self:IsSceneCamera()) then
			local filmmaker = tool.get_filmmaker()
			local actorEditor = filmmaker:GetActorEditor()
			if(util.is_valid(actorEditor)) then
				local actor = self:GetSceneCameraActorData()
				if(actor ~= nil) then
					self.m_inCameraLinkMode = true
					local workCam = self:GetWorkCamera()
					if(util.is_valid(workCam)) then self.m_cameraLinkModeWorkPose = workCam:GetEntity():GetPose() end
					local cam = self:GetSceneCamera()
					targetPose = cam:GetEntity():GetPose()
					self:SwitchToWorkCamera()
					actorEditor:ToggleCameraLink(actor)
				end
			end
		end
		self:SetGameplayMode(true)
		if(targetPose ~= nil) then self:SetWorkCameraPose(targetPose) end
		return
	end
	local scene = self.m_viewport:GetScene()
	local cam = util.is_valid(scene) and scene:GetActiveCamera() or nil
	if(util.is_valid(cam) == false or self.m_camStartPose == nil) then return end
	local pose = cam:GetEntity():GetPose()
	if(pose:GetOrigin():DistanceSqr(self.m_camStartPose:GetOrigin()) < 0.01 and pose:GetRotation():Distance(self.m_camStartPose:GetRotation()) < 0.01) then return end
	if(util.is_valid(self.m_rtViewport)) then self.m_rtViewport:MarkActorAsDirty(cam:GetEntity()) end
	self.m_camStartPose = pose:Copy()
end
function gui.PFMViewport:GetPlayButton() return self.m_btPlay end
function gui.PFMViewport:GetViewport() return self.m_viewport end
function gui.PFMViewport:OnSizeChanged(w,h)
	self:Update()
end
function gui.PFMViewport:OnUpdate()
	if(util.is_valid(self.m_timeLocal)) then
		self.m_timeLocal:SetX(self.m_titleBar:GetWidth() -self.m_timeLocal:GetWidth() -20)
	end
	self:UpdateFilmLabelPositions()
end
gui.register("WIPFMViewport",gui.PFMViewport)

function pfm.calc_decal_target_pose(pos,dir)
	local actor,hitPos,pos,hitData = pfm.raycast(pos,dir,2048.0)
	if(hitPos == nil) then return end
	local n = hitData:CalcHitNormal()
	local n2 = (math.abs(n:DotProduct(vector.UP)) < 0.999) and vector.UP or vector.FORWARD
	local n3 = n:Cross(n2)
	n3:Normalize()
	local rot = Quaternion(n,n3,n2)
	hitPos = hitPos +n *1.0
	return math.Transform(hitPos,rot)
end
