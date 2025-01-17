--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("pfm/controls_menu.lua")

local Element = util.register_class("gui.IkRigEditor",gui.Base)

local function get_bones_in_hierarchical_order(mdl)
	local bones = {}
	local function add_bones(bone,depth)
		depth = depth or 0
		table.insert(bones,{bone,depth})
		for boneId,child in pairs(bone:GetChildren()) do
			add_bones(child,depth +1)
		end
	end
	for boneId,bone in pairs(mdl:GetSkeleton():GetRootBones()) do
		add_bones(bone)
	end
	return bones
end

function Element:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(64,128)
	self.m_ikRig = ents.IkSolverComponent.RigConfig()
	self:UpdateModelView()

	local scrollContainer = gui.create("WIScrollContainer",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	scrollContainer:SetContentsWidthFixed(true)

	local controls = gui.create("WIPFMControlsMenu",scrollContainer,0,0,scrollContainer:GetWidth(),scrollContainer:GetHeight())
	controls:SetAutoFillContentsToHeight(false)
	controls:SetFixedHeight(false)
	self:SetThinkingEnabled(true)
	self.m_controls = controls

	local rootPath = "scripts/ik_rigs"
	local fe = controls:AddFileEntry("IK RIG","ik_rig","",function(resultHandler)
		local pFileDialog = gui.create_file_open_dialog(function(el,fileName)
			if(fileName == nil) then return end
			local rig = ents.IkSolverComponent.RigConfig.load(rootPath .. fileName)
			if(rig == nil) then
				pfm.log("Failed to load ik rig '" .. rootPath .. fileName .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_ERROR)
				return
			end

			self:LoadRig(rig)
		end)
		pFileDialog:SetRootPath(rootPath)
		pFileDialog:SetExtensions(ents.IkSolverComponent.RigConfig.get_supported_extensions())
		pFileDialog:Update()
	end)

	local feModel
	feModel = controls:AddFileEntry("Reference Model","reference_model","",function(resultHandler)
		local pFileDialog = gui.create_file_open_dialog(function(el,fileName)
			if(fileName == nil) then return end
			resultHandler(el:GetFilePath(true))
		end)
		pFileDialog:SetRootPath("models")
		pFileDialog:SetExtensions(asset.get_supported_extensions(asset.TYPE_MODEL))
		pFileDialog:Update()
	end)
	feModel:AddCallback("OnValueChanged",function(...)
		if(self.m_skipButtonCallbacks) then return end
		self:ReloadBoneList(feModel)
	end)
	self.m_feModel = feModel

	local el,wrapper = controls:AddDropDownMenu(locale.get_text("pfm_show_bones"),"show_bones",{{"0",locale.get_text("disabled")},{"1",locale.get_text("enabled")}},"0",function(el)
		self:UpdateBoneVisibility()
	end)
	self.m_elShowBones = el

	controls:AddButton(locale.get_text("save"),"save",function()
		local rig = self:GetRig()
		if(rig == nil) then return end
		local pFileDialog = gui.create_file_save_dialog(function(pDialoge,fileName)
			if(fileName == nil) then return end
			fileName = file.remove_file_extension(fileName,{"pikr","pikr_b"})
			local res,err = rig:Save("scripts/ik_rigs/" .. fileName .. ".pikr")
			if(res == false) then
				pfm.log("Failed to save ik rig: " .. err,pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_ERROR)
			end
		end)
		pFileDialog:SetRootPath("scripts/ik_rigs/")
		pFileDialog:Update()
	end)

	controls:ResetControls()
end
function Element:LoadRig(rig)
	self:Clear()
	self:ReloadBoneList(self.m_feModel)

	self.m_ikRig = rig
	for _,c in ipairs(rig:GetConstraints()) do
		local item = self.m_skelTree:GetRoot():GetItemByIdentifier(c.bone1,true)
		if(util.is_valid(item)) then
			if(c.type == ents.IkSolverComponent.RigConfig.Constraint.TYPE_FIXED) then
				self:AddFixedConstraint(item,c.bone1,c)
			elseif(c.type == ents.IkSolverComponent.RigConfig.Constraint.TYPE_HINGE) then
				self:AddHingeConstraint(item,c.bone1,c)
			elseif(c.type == ents.IkSolverComponent.RigConfig.Constraint.TYPE_BALL_SOCKET) then
				self:AddBallSocketConstraint(item,c.bone1,c)
			end
		end
	end
	self:ReloadIkRig()
end
function Element:UpdateMode()
	if(util.is_valid(self.m_modelView) == false or self.m_mdl == nil) then return end
	local ent = self.m_modelView:GetEntity(1)
	if(util.is_valid(ent) == false) then return end
	local mdl = ent:GetModel()
	if(mdl == nil) then return end

	local vc = self.m_modelView:GetViewerCamera()
	if(util.is_valid(vc)) then
		vc:FitViewToScene()
	end

	self.m_boneControlMenu:SetVisible(true)
	self.m_modelView:Render()

	self:UpdateBoneVisibility()
end
function Element:Clear()
	self.m_skelTree:Clear()
end
function Element:SetModel(impostee)
	if(util.is_valid(self.feModel)) then self.feModel:SetValue(impostee) end
end
function Element:ReloadBoneList(feModel)
	local pathMdl = feModel:GetValue()
	if(#pathMdl == 0) then return end
	local mdl = game.load_model(pathMdl)
	if(mdl == nil) then return end
	self.m_mdl = mdl

	self:AddBoneList()
	if(util.is_valid(self.m_mdlView)) then
		self:LinkToModelView(self.m_mdlView)
		self:InitializeModelView()
	end
	self:UpdateMode()

	self.m_ikRig = ents.IkSolverComponent.RigConfig()
end
function Element:OnRemove()
	self:UnlinkFromModelView()
	util.remove(self.m_entTransformGizmo)
	util.remove(self.m_trOnGizmoControlAdded)
	util.remove(self.m_cbOnAnimsUpdated)
end
function Element:OnSizeChanged(w,h)
	if(util.is_valid(self.m_controls)) then self.m_controls:SetWidth(w) end
end
function Element:LinkToModelView(mv) self.m_modelView = mv end
function Element:UnlinkFromModelView()
	if(util.is_valid(self.m_modelView) == false) then return end
	local mdlView = self.m_modelView
	mdlView:RemoveActor(2)
	local ent = mdlView:GetEntity(1)
	if(util.is_valid(ent)) then ent:SetPos(Vector()) end
	self.m_modelView = nil
end
function Element:UpdateBoneVisibility()
	local enabled = toboolean(self.m_elShowBones:GetOptionValue(self.m_elShowBones:GetSelectedOption()))
	if(util.is_valid(self.m_mdlView) == false) then return end
	local tEnts = {}

	local ent = self.m_mdlView:GetEntity(1)
	if(util.is_valid(ent)) then table.insert(tEnts,ent) end

	for i,ent in ipairs(tEnts) do
		if(enabled) then
			local debugC = ent:AddComponent("debug_skeleton_draw")
			if(debugC ~= nil) then
				if(i == 1) then debugC:SetColor(Color.Orange)
				else debugC:SetColor(Color.Aqua) end
			end
		else ent:RemoveComponent("debug_skeleton_draw") end
	end
	self.m_mdlView:Render()
end
function Element:InitializeModelView()
	if(util.is_valid(self.m_modelView) == false) then return end
	local ent = self.m_modelView:GetEntity(1)
	if(util.is_valid(ent) == false) then return end
	self.m_modelView:SetModel(self.m_mdl)
	self.m_modelView:PlayAnimation("reference",1)
	self:UpdateMode()
	return ent
end
function Element:AddBoneList()
	local mdl = self.m_mdl
	if(mdl == nil) then return end

	util.remove(self.m_rigControls)
	self.m_rigControls = self.m_controls:AddSubMenu()
	self.m_boneControlMenu = self.m_rigControls:AddSubMenu()
	self:InitializeBoneControls(mdl)

	gui.create("WIBase",self.m_rigControls) -- Dummy
end
function Element:SetBoneColor(actorId,boneId,col)
	if(boneId == nil) then
		if(self.m_origBoneColor == nil or self.m_origBoneColor[actorId] == nil) then return end
		for boneId,_ in pairs(self.m_origBoneColor) do
			self:SetBoneColor(actorId,boneId,col)
		end
		return
	end

	local ent = util.is_valid(self.m_mdlView) and self.m_mdlView:GetEntity(actorId) or nil
	local debugC = util.is_valid(ent) and ent:AddComponent("debug_skeleton_draw") or nil
	if(debugC == nil) then return end
	local entBone = debugC:GetBoneEntity(boneId)
	if(util.is_valid(entBone) == false) then return end
	if(col == nil) then
		if(self.m_origBoneColor == nil or self.m_origBoneColor[actorId] == nil or self.m_origBoneColor[actorId][boneId] == nil) then return end
		col = self.m_origBoneColor[actorId][boneId]
		self.m_origBoneColor[actorId][boneId] = nil
	else
		self.m_origBoneColor = self.m_origBoneColor or {}
		self.m_origBoneColor[actorId] = self.m_origBoneColor[actorId] or {}
		self.m_origBoneColor[actorId][boneId] = self.m_origBoneColor[actorId][boneId] or entBone:GetColor()
	end
	entBone:SetColor(col)
	self.m_mdlView:Render()
end
function Element:InitializeBoneControls(mdl)
	local options = {}
	table.insert(options,{"none","-"})
	table.insert(options,{"hinge","Hinge"})
	table.insert(options,{"ballsocket","BallSocket"})

	util.remove(self.m_skelTreeSubMenu)
	local subMenu = self.m_boneControlMenu:AddSubMenu()
	self.m_skelTreeSubMenu = subMenu
	local tree = gui.create("WIPFMTreeView",subMenu,0,0,subMenu:GetWidth(),20)
	self.m_skelTree = tree
	tree:SetSelectable(gui.Table.SELECTABLE_MODE_SINGLE)

	local bones = get_bones_in_hierarchical_order(mdl)
	for _,boneInfo in ipairs(bones) do
		local boneDst = boneInfo[1]
		local depth = boneInfo[2]
		local name = string.rep("  ",depth) .. boneDst:GetName()

		local item = tree:AddItem(name)
		item:SetIdentifier(boneDst:GetName())
		item:AddCallback("OnSelectionChanged",function(pItem,selected)
			util.remove(self.m_cbOnAnimsUpdated)
			self:ReloadIkRig()
			self:CreateTransformGizmo()
		end)
		item:AddCallback("OnMouseEvent",function(wrapper,button,state,mods)
			if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
				local pContext = gui.open_context_menu()
				if(util.is_valid(pContext)) then
					pContext:SetPos(input.get_cursor_pos())
					pContext:AddItem("Add Fixed Constraint",function()
						self:AddFixedConstraint(item,boneDst:GetName())
					end)
					pContext:AddItem("Add Hinge Constraint",function()
						self:AddHingeConstraint(item,boneDst:GetName())
					end)
					pContext:AddItem("Add Ball Socket Constraint",function()
						self:AddBallSocketConstraint(item,boneDst:GetName())
					end)
					if(self.m_ikRig:HasBone(boneDst:GetName())) then
						pContext:AddItem("Remove Bone",function()
							self.m_ikRig:RemoveBone(boneDst:GetName())
							self:ReloadIkRig()
						end)
					else
						pContext:AddItem("Add Bone",function()
							self.m_ikRig:AddBone(boneDst:GetName())
							self:ReloadIkRig()
						end)
					end
					if(self.m_ikRig:IsBoneLocked(boneDst:GetName())) then
						pContext:AddItem("Unlock Bone",function()
							self.m_ikRig:SetBoneLocked(boneDst:GetName(),false)
							self:ReloadIkRig()
						end)
					else
						pContext:AddItem("Lock Bone",function()
							self.m_ikRig:SetBoneLocked(boneDst:GetName(),true)
							self:ReloadIkRig()
						end)
					end
					if(self.m_ikRig:HasControl(boneDst:GetName())) then
						pContext:AddItem("Remove Control",function()
							self.m_ikRig:RemoveControl(boneDst:GetName())
							self:ReloadIkRig()
						end)
					else
						pContext:AddItem("Add Drag Control",function()
							self.m_ikRig:AddControl(boneDst:GetName(),ents.IkSolverComponent.RigConfig.Control.TYPE_DRAG)
							self:ReloadIkRig()
						end)
						pContext:AddItem("Add State Control",function()
							self.m_ikRig:AddControl(boneDst:GetName(),ents.IkSolverComponent.RigConfig.Control.TYPE_STATE)
							self:ReloadIkRig()
						end)
					end
					pContext:Update()
					return util.EVENT_REPLY_HANDLED
				end
				return util.EVENT_REPLY_HANDLED
			end
		end)
	end
	self.m_boneControlMenu:ResetControls()
end
function Element:AddConstraint(item,boneName,type,constraint)
	local ent = self.m_modelView:GetEntity(1)
	if(util.is_valid(ent) == false) then return end
	local mdl = ent:GetModel()
	if(mdl == nil) then return end
	local skel = mdl:GetSkeleton()
	local boneId = skel:LookupBone(boneName)
	local bone = skel:GetBone(boneId)
	local parent = bone:GetParent()
	self.m_ikRig:AddBone(boneName)
	self.m_ikRig:AddBone(parent:GetName())

	local child = item:AddItem(type .. " Constraint")
	child:AddCallback("OnMouseEvent",function(wrapper,button,state,mods)
		if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
			local pContext = gui.open_context_menu()
			if(util.is_valid(pContext)) then
				pContext:SetPos(input.get_cursor_pos())
				pContext:AddItem("Remove",function()
					self.m_ikRig:RemoveConstraint(constraint)
					child:RemoveSafely()
					item:ScheduleUpdate()
					self:ReloadIkRig()
				end)
				pContext:Update()
				return util.EVENT_REPLY_HANDLED
			end
			return util.EVENT_REPLY_HANDLED
		end
	end)

	local ctrlsParent = child:AddItem("")
	local crtl = gui.create("WIPFMControlsMenu",ctrlsParent,0,0,ctrlsParent:GetWidth(),ctrlsParent:GetHeight())
	crtl:SetAutoAlignToParent(true,false)
	crtl:SetAutoFillContentsToHeight(false)

	local singleAxis
	local minLimits,maxLimits
	local function add_rotation_axis_slider(name,axisId,min,defVal)
		crtl:AddSliderControl("Rot " .. name,"rot_" .. name,defVal,-180.0,180.0,function(el,value)
			local animatedC = ent:GetComponent(ents.COMPONENT_ANIMATED)
			if(animatedC ~= nil) then
				local ref = mdl:GetReferencePose()
				local pose = ref:GetBonePose(parent:GetID()):GetInverse() *ref:GetBonePose(boneId)
				local rot = pose:GetRotation():ToEulerAngles()
				local tAxisId = singleAxis or axisId
				rot:Set(tAxisId,rot:Get(tAxisId) +value)
				pose:SetRotation(rot)
				ent:RemoveComponent(ents.COMPONENT_IK_SOLVER)
				ent:RemoveComponent(ents.COMPONENT_PFM_FBIK)

				util.remove(self.m_cbOnAnimsUpdated)
				self.m_cbOnAnimsUpdated = ent:GetComponent(ents.COMPONENT_ANIMATED):AddEventCallback(ents.AnimatedComponent.EVENT_ON_ANIMATIONS_UPDATED,function()

					animatedC:SetBonePose(boneId,pose)
				end)

				self.m_mdlView:Render()

				if(min) then minLimits:Set(singleAxis and 0 or tAxisId,value)
				else maxLimits:Set(singleAxis and 0 or tAxisId,value) end
				constraint.minLimits = minLimits
				constraint.maxLimits = maxLimits
			end
		end,0.01)
	end

	if(constraint == nil) then
		pfm.log("Adding " .. type .. " constraint from bone '" .. parent:GetName() .. "' to '" .. bone:GetName() .. "' of actor with model '" .. mdl:GetName() .. "'...",pfm.LOG_CATEGORY_PFM)
		if(type == "fixed") then constraint = self.m_ikRig:AddFixedConstraint(parent:GetName(),bone:GetName())
		elseif(type == "hinge") then constraint = self.m_ikRig:AddHingeConstraint(parent:GetName(),bone:GetName(),-90.0,90.0)
		elseif(type == "ballSocket") then constraint = self.m_ikRig:AddBallSocketConstraint(parent:GetName(),bone:GetName(),EulerAngles(-90,-90,-0.5),EulerAngles(90,90,0.5)) end
	end
	minLimits = constraint.minLimits
	maxLimits = constraint.maxLimits

	local function add_rotation_axis(name,axisId,defMin,defMax)
		add_rotation_axis_slider(name .. " min",axisId,true,defMin)
		add_rotation_axis_slider(name .. " max",axisId,false,defMax)
	end
	if(type == "ballSocket") then
		add_rotation_axis("pitch",0,minLimits.p,maxLimits.p)
		add_rotation_axis("yaw",1,minLimits.y,maxLimits.y)
		add_rotation_axis("roll",2,minLimits.r,maxLimits.r)
	elseif(type == "hinge") then
		singleAxis = 0
		crtl:AddDropDownMenu("Axis","axis",{
			{"x",locale.get_text("x")},
			{"y",locale.get_text("y")},
			{"z",locale.get_text("z")}
		},0,function(el,option)
			singleAxis = el:GetSelectedOption()
		end)
		add_rotation_axis("angle",nil,minLimits.p,maxLimits.p)
	end
	crtl:ResetControls()
	crtl:Update()
	crtl:SizeToContents()

	self:ReloadIkRig()
	return constraint
end
function Element:AddBallSocketConstraint(item,boneName,c)
	return self:AddConstraint(item,boneName,"ballSocket",c)
end
function Element:AddHingeConstraint(item,boneName,c)
	return self:AddConstraint(item,boneName,"hinge",c)
end
function Element:AddFixedConstraint(item,boneName,c)
	return self:AddConstraint(item,boneName,"fixed",c)
end
function Element:ReloadIkRig()
	local entActor = self.m_mdlView:GetEntity(1)
	local pfmFbIkC = entActor:AddComponent("pfm_fbik")
	local ikSolverC = entActor:GetComponent(ents.COMPONENT_IK_SOLVER)
	if(ikSolverC == nil) then return end
	ikSolverC:ResetIkRig() -- Clear Rig
	ikSolverC:AddIkSolverByRig(self.m_ikRig)
end
function Element:CreateTransformGizmo()
	local selectedElements = self.m_skelTree:GetSelectedElements()
	local selectedItem = pairs(selectedElements)(selectedElements)
	util.remove(self.m_entTransformGizmo)
	if(util.is_valid(selectedItem) == false) then return end
	local boneName = selectedItem:GetIdentifier()
	if(self.m_ikRig:HasControl(boneName) == false) then return end
	local entTransform = ents.create("util_transform")
	self.m_entTransformGizmo = entTransform
	entTransform:Spawn()

	local entActor = self.m_mdlView:GetEntity(1)
	if(util.is_valid(entActor)) then entTransform:SetPos(entActor:GetPos()) end
	local trC = entTransform:GetComponent("util_transform")
	util.remove(self.m_trOnGizmoControlAdded)
	self.m_trOnGizmoControlAdded = trC:AddEventCallback(ents.UtilTransformComponent.EVENT_ON_GIZMO_CONTROL_ADDED,function(ent)
		ent:RemoveFromScene(game.get_scene())
		ent:AddToScene(self.m_mdlView:GetScene())
	end)
	if(trC ~= nil) then
		trC:SetTranslationEnabled(true)
		trC:SetRotationEnabled(false)
		trC:SetScaleEnabled(false)

		local ikSolverC = entActor:GetComponent(ents.COMPONENT_IK_SOLVER)
		local memberPath = "control/" .. boneName .. "/position"
		local pos = ikSolverC:GetMemberValue(memberPath)
		local localPose = math.Transform(pos)
		local pose = entActor:GetPose()
		entTransform:SetPose(pose *localPose)
		self.m_mdlView:Render()
		trC:AddEventCallback(ents.UtilTransformComponent.EVENT_ON_POSITION_CHANGED,function(pos)
			self.m_mdlView:Render()
			local absPose = math.Transform(pos)
			local localPose = entActor:GetPose():GetInverse() *absPose
			ikSolverC:SetMemberValue(memberPath,localPose:GetOrigin())
		end)
		--[[utilTransformC:AddEventCallback(ents.UtilTransformComponent.EVENT_ON_ROTATION_CHANGED,function(rot)
			local localRot = rot:Copy()
			if(animC ~= nil) then
				local pose = animC:GetGlobalBonePose(boneId)
				pose:SetRotation(rot)
				animC:SetGlobalBonePose(boneId,pose)

				localRot = animC:GetBoneRot(boneId)
			end
			self:BroadcastEvent(ents.UtilBoneTransformComponent.EVENT_ON_ROTATION_CHANGED,{boneId,rot,localRot})
		end)
		utilTransformC:AddEventCallback(ents.UtilTransformComponent.EVENT_ON_SCALE_CHANGED,function(scale)
			if(animC ~= nil) then
				local pose = animC:GetGlobalBonePose(boneId)
				pose:SetScale(scale)
				animC:SetGlobalBonePose(boneId,pose)
			end
			self:BroadcastEvent(ents.UtilBoneTransformComponent.EVENT_ON_SCALE_CHANGED,{boneId,scale,scale})
		end)
		utilTransformC:AddEventCallback(ents.UtilTransformComponent.EVENT_ON_TRANSFORM_END,function()
			self:BroadcastEvent(ents.UtilBoneTransformComponent.EVENT_ON_TRANSFORM_END)
		end)]]
	end

	entTransform:RemoveFromScene(game.get_scene())
	entTransform:AddToScene(self.m_mdlView:GetScene())
	trC:SetCamera(self.m_mdlView:GetCamera())
end
function Element:UpdateModelView()
	self.m_tUpdateModelView = time.real_time()
end
function Element:OnThink()
	if(time.real_time() -self.m_tUpdateModelView < 0.25) then
		if(util.is_valid(self.m_modelView)) then self.m_modelView:Render() end
	end
end
function Element:SetModelView(mdlView) self.m_mdlView = mdlView end
function Element:GetRig() return self.m_ikRig end
gui.register("WIIkRigEditor",Element)
