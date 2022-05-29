--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("slider.lua")
include("treeview.lua")
include("weightslider.lua")
include("controls_menu.lua")
include("entry_edit_window.lua")
include("/pfm/component_manager.lua")
include("/pfm/component_actions.lua")

util.register_class("gui.PFMActorEditor",gui.Base)

function gui.PFMActorEditor:__init()
	gui.Base.__init(self)
end
function gui.PFMActorEditor:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(64,128)

	self.m_bg = gui.create("WIRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_bg:SetColor(Color(54,54,54))

	self.navBar = gui.create("WIHBox",self)
	self:InitializeNavigationBar()

	self.navBar:SetHeight(32)
	self.navBar:SetAnchor(0,0,1,0)
	self.m_activeControls = {}

	self.m_btTools = gui.PFMButton.create(self,"gui/pfm/icon_gear","gui/pfm/icon_gear_activated",function()
		print("TODO")
	end)
	self.m_btTools:SetX(self:GetWidth() -self.m_btTools:GetWidth())
	self.m_btTools:SetupContextMenu(function(pContext)
		pContext:AddItem(locale.get_text("pfm_create_new_actor"),function()
			if(self:IsValid() == false) then return end
			local actor = self:CreateNewActor()
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_articulated_actor"),function()
			gui.open_model_dialog(function(dialogResult,mdlName)
				if(dialogResult ~= gui.DIALOG_RESULT_OK) then return end
				if(self:IsValid() == false) then return end
				self:CreateNewPropActor(mdlName)
			end)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_prop"),function()
			gui.open_model_dialog(function(dialogResult,mdlName)
				if(dialogResult ~= gui.DIALOG_RESULT_OK) then return end
				if(self:IsValid() == false) then return end
				local actor = self:CreateNewActor()
				if(actor == nil) then return end
				local mdlC = self:CreateNewActorComponent(actor,"pfm_model",false,function(mdlC) actor:ChangeModel(mdlName) end)
				self:CreateNewActorComponent(actor,"model",false)
				self:CreateNewActorComponent(actor,"render",false)
				-- self:CreateNewActorComponent(actor,"transform",false)
				self:UpdateActorComponents(actor)
			end)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_camera"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_camera",false)
			-- self:CreateNewActorComponent(actor,"toggle",false)
			self:CreateNewActorComponent(actor,"camera",false)
			-- self:CreateNewActorComponent(actor,"transform",false)
			self:UpdateActorComponents(actor)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_particle_system"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_particle_system",false)
			self:UpdateActorComponents(actor)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_spot_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_spot",false)
			local lightC = self:CreateNewActorComponent(actor,"light",false)
			local lightSpotC = self:CreateNewActorComponent(actor,"light_spot",false)
			local radiusC = self:CreateNewActorComponent(actor,"radius",false)
			self:CreateNewActorComponent(actor,"color",false)
			-- self:CreateNewActorComponent(actor,"transform",false)
			lightSpotC:SetMemberValue("blendFraction",udm.TYPE_FLOAT,0.1)
			lightSpotC:SetMemberValue("outerConeAngle",udm.TYPE_FLOAT,60.0)
			lightC:SetMemberValue("intensity",udm.TYPE_FLOAT,1000)
			lightC:SetMemberValue("castShadows",udm.TYPE_BOOLEAN,false)
			radiusC:SetMemberValue("radius",udm.TYPE_FLOAT,1000)
			self:UpdateActorComponents(actor)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_point_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_point",false)
			local lightC = self:CreateNewActorComponent(actor,"light",false)
			self:CreateNewActorComponent(actor,"light_point",false)
			local radiusC = self:CreateNewActorComponent(actor,"radius",false)
			self:CreateNewActorComponent(actor,"color",false)
			-- self:CreateNewActorComponent(actor,"transform",false)
			lightC:SetMemberValue("intensity",udm.TYPE_FLOAT,1000)
			lightC:SetMemberValue("castShadows",udm.TYPE_BOOLEAN,false)
			radiusC:SetMemberValue("radius",udm.TYPE_FLOAT,1000)
			self:UpdateActorComponents(actor)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_directional_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_directional",false)
			local lightC = self:CreateNewActorComponent(actor,"light",false)
			self:CreateNewActorComponent(actor,"light_directional",false)
			self:CreateNewActorComponent(actor,"color",false)
			-- self:CreateNewActorComponent(actor,"transform",false)
			lightC:SetMemberValue("intensity",udm.TYPE_FLOAT,30.0)
			lightC:SetMemberValue("intensityType",udm.TYPE_UINT8,ents.LightComponent.INTENSITY_TYPE_LUX)
			lightC:SetMemberValue("castShadows",udm.TYPE_BOOLEAN,false)

			local cActor = actor:FindComponent("pfm_actor")
			if(cActor ~= nil) then
				local rot = cActor:GetMemberValue("rotation")
				if(rot ~= nil) then
					rot = rot:ToEulerAngles()
					rot.p = 45.0
					cActor:SetMemberValue("rotation",udm.TYPE_QUATERNION,rot:ToQuaternion())
				end
			end

			self:UpdateActorComponents(actor)
		end)
		--[[pContext:AddItem(locale.get_text("pfm_create_new_volume_simple"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			local mdlC = self:CreateNewActorComponent(actor,"pfm_model",false,function(mdlC) actor:ChangeModel("cube_volumetric") end)
			self:CreateNewActorComponent(actor,"pfm_volumetric",false)

			local transform = actor:GetTransform()
			transform:SetScale(Vector(10,10,10))
			actor:SetTransform(transform)
			self:UpdateActorComponents(actor)
		end)]]
		pContext:AddItem(locale.get_text("pfm_create_new_volume"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			local mdlC = self:CreateNewActorComponent(actor,"pfm_model",false,function(mdlC) actor:ChangeModel("cube") end)
			self:CreateNewActorComponent(actor,"pfm_volumetric",false)

			-- Calc scene extents
			local min = Vector(math.huge,math.huge,math.huge)
			local max = Vector(-math.huge,-math.huge,-math.huge)
			for ent in ents.iterator({ents.IteratorFilterComponent(ents.COMPONENT_RENDER)}) do
				local renderC = ent:GetComponent(ents.COMPONENT_RENDER)
				local rMin,rMax = renderC:GetAbsoluteRenderBounds()
				for i=0,2 do
					min:Set(i,math.min(min:Get(i),rMin:Get(i)))
					max:Set(i,math.max(max:Get(i),rMax:Get(i)))
				end
			end
			if(min.x == math.huge) then
				min = Vector()
				max = Vector()
			end
			local center = (min +max) /2.0
			min = min -center
			max = max -center
			local extents = (max -min) /2.0
			pfm.log("Setting volume extents to " .. tostring(extents) .. ".",pfm.LOG_CATEGORY_PFM)

			local transform = math.ScaledTransform()
			transform:SetOrigin(center)
			transform:SetRotation(Quaternion())
			transform:SetScale(extents)
			actor:SetTransform(transform)
			self:UpdateActorComponents(actor)
		end)

		local pBakingItem,pBakingMenu = pContext:AddSubMenu(locale.get_text("pfm_baking"))
		pBakingMenu:AddItem(locale.get_text("pfm_create_lightmapper"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_baked_lighting")
			self:UpdateActorComponents(actor)
		end)
		pBakingMenu:AddItem(locale.get_text("pfm_create_reflection_probe"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			local c = self:CreateNewActorComponent(actor,"reflection_probe",false)
			c:SetMemberValue("iblStrength",udm.TYPE_FLOAT,1.4)
			c:SetMemberValue("iblMaterial",udm.TYPE_STRING,"pbr/ibl/venice_sunset")
			self:UpdateActorComponents(actor)
		end)
		pBakingMenu:Update()

		local filmClip = self:GetFilmClip()
		local hasSkyComponent = false
		if(filmClip ~= nil) then
			for _,actor in ipairs(filmClip:GetActorList()) do
				local c = actor:FindComponent("pfm_sky")
				if(c ~= nil) then
					hasSkyComponent = true
					break
				end
			end
		end
		if(hasSkyComponent == false) then
			pContext:AddItem(locale.get_text("pfm_add_sky"),function() self:AddSkyActor() end)
		end

		--[[local pEntsItem,pEntsMenu = pContext:AddSubMenu(locale.get_text("pfm_add_preset"))
		local types = ents.get_registered_entity_types()
		table.sort(types)
		for _,typeName in ipairs(types) do
			pEntsMenu:AddItem(typeName,function()
				local actor = self:CreateNewActor()
				if(actor == nil) then return end
				-- TODO: Add entity core components

				self:AddActorToScene(actor)
			end)
		end
		pEntsMenu:Update()]]

		--[[local history = self:GetHistory()
		local pos = history:GetCurrentPosition()
		local numItems = #history
		if(pos < numItems) then
			for i=pos +1,numItems do
				local el = history:Get(i)
				pContext:AddItem(el:GetName(),function()
					history:SetCurrentPosition(i)
				end)
			end
		end
		pContext:AddLine()
		pContext:AddItem(locale.get_text("pfm_reset_history"),function()
			history:Clear()
		end)]]
	end,true)

	self.m_contents = gui.create("WIHBox",self,
		0,self.m_btTools:GetBottom(),self:GetWidth(),self:GetHeight() -self.m_btTools:GetBottom(),
		0,0,1,1
	)
	self.m_contents:SetAutoFillContents(true)

	local treeScrollContainerBg = gui.create("WIRect",self.m_contents,0,0,64,128)
	treeScrollContainerBg:SetColor(Color(38,38,38))
	local treeScrollContainer = gui.create("WIScrollContainer",treeScrollContainerBg,0,0,64,128,0,0,1,1)
	treeScrollContainerBg:AddCallback("SetSize",function(el)
		if(self:IsValid() and util.is_valid(self.m_tree)) then
			self.m_tree:SetWidth(el:GetWidth())
		end
	end)
	--treeScrollContainer:SetFixedSize(true)
	--[[local bg = gui.create("WIRect",treeScrollContainer,0,0,treeScrollContainer:GetWidth(),treeScrollContainer:GetHeight(),0,0,1,1)
	bg:SetColor(Color(38,38,38))
	treeScrollContainer:SetBackgroundElement(bg)]]


	local resizer = gui.create("WIResizer",self.m_contents)
	local dataVBox = gui.create("WIVBox",self.m_contents)
	dataVBox:SetFixedSize(true)
	dataVBox:SetAutoFillContentsToWidth(true)
	dataVBox:SetAutoFillContentsToHeight(true)

	local propertiesHBox = gui.create("WIHBox",dataVBox)
	propertiesHBox:SetAutoFillContents(true)
	self.m_propertiesHBox = propertiesHBox

	local propertiesLabelsVBox = gui.create("WIVBox",propertiesHBox)
	propertiesLabelsVBox:SetAutoFillContentsToWidth(true)
	self.m_propertiesLabelsVBox = propertiesLabelsVBox

	gui.create("WIResizer",propertiesHBox)

	local propertiesElementsVBox = gui.create("WIVBox",propertiesHBox)
	propertiesElementsVBox:SetAutoFillContentsToWidth(true)
	self.m_propertiesElementsVBox = propertiesElementsVBox

	gui.create("WIResizer",dataVBox)

	local animSetControls
		local scrollContainer = gui.create("WIScrollContainer",dataVBox)
		scrollContainer:AddCallback("SetSize",function(el)
			if(self:IsValid() and util.is_valid(animSetControls)) then
				animSetControls:SetWidth(el:GetWidth())
			end
		end)

	animSetControls = gui.create("WIPFMControlsMenu",scrollContainer,0,0,scrollContainer:GetWidth(),scrollContainer:GetHeight())
	animSetControls:SetAutoFillContentsToWidth(true)
	animSetControls:SetAutoFillContentsToHeight(false)
	animSetControls:SetFixedHeight(false)
	animSetControls:AddCallback("OnControlAdded",function(el,name,ctrl,wrapper)
		if(wrapper ~= nil) then
			wrapper:AddCallback("OnValueChanged",function()
				local filmmaker = tool.get_filmmaker()
				filmmaker:TagRenderSceneAsDirty()
			end)
		end
	end)
	self.m_animSetControls = animSetControls

	self.m_sliderControls = {}

	self.m_tree = gui.create("WIPFMTreeView",treeScrollContainer,0,0,treeScrollContainer:GetWidth(),treeScrollContainer:GetHeight())
	self.m_tree:SetSelectable(gui.Table.SELECTABLE_MODE_MULTI)
	self.m_treeElementToActorData = {}
	self.m_actorUniqueIdToTreeElement = {}
	self.m_tree:AddCallback("OnItemSelectChanged",function(tree,el,selected)
		local queue = {}
		if(self.m_dirtyActorEntries ~= nil) then
			for uniqueId,_ in pairs(self.m_dirtyActorEntries) do
				table.insert(queue,uniqueId)
			end
		end
		for _,uniqueId in ipairs(queue) do
			self:InitializeDirtyActorComponents(uniqueId)
		end
		self:ScheduleUpdateSelectedEntities()
	end)
	--[[self.m_data = gui.create("WITable",dataVBox,0,0,dataVBox:GetWidth(),dataVBox:GetHeight(),0,0,1,1)

	self.m_data:SetRowHeight(self.m_tree:GetRowHeight())
	self.m_data:SetSelectableMode(gui.Table.SELECTABLE_MODE_SINGLE)]]

	self.m_componentManager = pfm.ComponentManager()

	self.m_leftRightWeightSlider = gui.create("WIPFMWeightSlider",self.m_animSetControls)

	self:SetMouseInputEnabled(true)
end
function gui.PFMActorEditor:AddSkyActor()
	self:CreateNewActorWithComponents("sky",{"pfm_actor","pfm_sky"})
end
function gui.PFMActorEditor:CreateNewPropActor(mdlName,origin,rotation,actorName)
	local pose
	if(origin ~= nil or rotation ~= nil) then
		pose = math.Transform()
		if(origin ~= nil) then pose:SetOrigin(origin) end
		if(rotation ~= nil) then pose:SetRotation(rotation) end
	end
	local actor = self:CreateNewActor(actorName,pose)
	if(actor == nil) then return end
	local mdlC = self:CreateNewActorComponent(actor,"pfm_model",false,function(mdlC) actor:ChangeModel(mdlName) end)
	self:CreateNewActorComponent(actor,"model",false)
	self:CreateNewActorComponent(actor,"render",false)
	-- self:CreateNewActorComponent(actor,"transform",false)

	self:UpdateActorComponents(actor)
	return actor
end
function gui.PFMActorEditor:CreateNewActorWithComponents(name,components)
	local actor = self:CreateNewActor(name)
	if(actor == nil) then return end
	for i,componentName in ipairs(components) do
		if(type(componentName) == "table") then
			self:CreateNewActorComponent(actor,componentName[1],i == #components,componentName[2])
		else
			self:CreateNewActorComponent(actor,componentName,i == #components)
		end
	end
	self:UpdateActorComponents(actor)
	return actor
end
function gui.PFMActorEditor:GetTree() return self.m_tree end
function gui.PFMActorEditor:GetActorItem(actor)
	for item,actorData in pairs(self.m_treeElementToActorData) do
		if(util.is_same_object(actorData.actor,actor)) then return item end
	end
end
function gui.PFMActorEditor:GetActorComponentItem(actor,componentName)
	local item = self:GetActorItem(actor)
	if(item == nil) then return end
	if(self.m_treeElementToActorData == nil or self.m_treeElementToActorData[item] == nil) then return end
	local item = self.m_treeElementToActorData[item].componentsEntry
	if(util.is_valid(item) == false) then return end
	return item:GetItemByIdentifier(componentName)
end
function gui.PFMActorEditor:CreateNewActor(actorName,pose)
	local filmClip = self:GetFilmClip()
	if(filmClip == nil) then
		pfm.create_popup_message(locale.get_text("pfm_popup_create_actor_no_film_clip"))
		return
	end
	local actor = pfm.get_project_manager():AddActor(self:GetFilmClip())
	if(actorName == nil) then
		actorName = "actor"

		local actorIndex = 1
		while(filmClip:FindActor(actorName .. actorIndex) ~= nil) do actorIndex = actorIndex +1 end
		actorName = actorName .. actorIndex
	end
	actor:SetName(actorName)

	local pos,rot
	if(pose ~= nil) then
		pos = pose:GetOrigin()
		rot = pose:GetRotation()
	else
		pos = Vector()
		rot = Quaternion()
		local cam = tool.get_filmmaker():GetActiveCamera()
		if(util.is_valid(cam)) then
			local entCam = cam:GetEntity()
			pos = entCam:GetPos() +entCam:GetForward() *100.0
			rot = EulerAngles(0,entCam:GetAngles().y,0):ToQuaternion()
		end
	end

	self:AddActor(actor)

	local pfmActorC = self:CreateNewActorComponent(actor,"pfm_actor",false)
	pfmActorC:SetMemberValue("position",udm.TYPE_VECTOR3,pos)
	pfmActorC:SetMemberValue("rotation",udm.TYPE_QUATERNION,rot)

	return actor
end
function gui.PFMActorEditor:CreateNewActorComponent(actor,componentType,updateActorAndUi,initComponent)
	if(updateActorAndUi == nil) then updateActorAndUi = true end
	local itemActor
	for elTree,data in pairs(self.m_treeElementToActorData) do
		if(util.is_same_object(actor,data.actor)) then
			itemActor = elTree
			break
		end
	end

	if(itemActor == nil) then return end

	local componentId = ents.find_component_id(componentType)
	if(componentId == nil) then include_component(componentType) end
	componentId = ents.find_component_id(componentType)
	if(componentId == nil) then pfm.log("Attempted to add unknown entity component '" .. componentType .. "' to actor '" .. tostring(actor) .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING) return end

	local component = actor:AddComponentType(componentType)
	if(initComponent ~= nil) then initComponent(component) end

	if(updateActorAndUi == true) then self:UpdateActorComponents(actor) end

	return component
end
function gui.PFMActorEditor:UpdateActorComponents(actor)
	tool.get_filmmaker():UpdateActor(actor,self:GetFilmClip(),true)

	local itemActor
	for elTree,data in pairs(self.m_treeElementToActorData) do
		if(util.is_same_object(actor,data.actor)) then
			itemActor = elTree
			break
		end
	end

	if(itemActor == nil) then return end

	local actorData = self.m_treeElementToActorData[itemActor]
	self:UpdateActorComponentEntries(actorData)
end
function gui.PFMActorEditor:TagRenderSceneAsDirty(dirty)
	tool.get_filmmaker():TagRenderSceneAsDirty(dirty)
end
local function applyComponentChannelValue(actorEditor,component,controlData,value)
	local actor = component:GetActor()
	if(actor ~= nil and controlData.path ~= nil) then
		actorEditor:SetAnimationChannelValue(actor,controlData.path,value)
	end
end
function gui.PFMActorEditor:AddSliderControl(component,controlData)
	if(util.is_valid(self.m_animSetControls) == false) then return end

	local function applyValue(value)
		local actor = component:GetActor()
		if(actor ~= nil and controlData.path ~= nil) then
			self:SetAnimationChannelValue(actor,controlData.path,value)
		end
	end

	local slider = self.m_animSetControls:AddSliderControl(
		controlData.name,controlData.identifier,controlData.translateToInterface(controlData.default or 0.0),
		controlData.translateToInterface(controlData.min or 0.0),controlData.translateToInterface(controlData.max or 100),nil,nil,
		controlData.integer or controlData.boolean
	)
	if(controlData.default ~= nil) then slider:SetDefault(controlData.translateToInterface(controlData.default)) end

	if(controlData.getValue ~= nil) then
		local val = controlData.getValue()
		if(val ~= nil) then slider:SetValue(controlData.translateToInterface(val)) end
	end

	local callbacks = {}
	local skipCallbacks
	if(controlData.type == "flexController") then
		if(controlData.dualChannel == true) then
			slider:GetLeftRightValueRatioProperty():Link(self.m_leftRightWeightSlider:GetFractionProperty())
		end
		if(controlData.property ~= nil) then
			slider:SetValue(controlData.translateToInterface(component:GetProperty(controlData.property):GetValue()))
		elseif(controlData.get ~= nil) then
			slider:SetValue(controlData.translateToInterface(controlData.get(component)))
			if(controlData.getProperty ~= nil) then
				local prop = controlData.getProperty(component)
				if(prop ~= nil) then
					local cb = prop:AddChangeListener(function(newValue)
						self:TagRenderSceneAsDirty()
						if(skipCallbacks) then return end
						skipCallbacks = true
						slider:SetValue(controlData.translateToInterface(newValue))
						skipCallbacks = nil
					end)
					table.insert(callbacks,cb)
				end
			end
		elseif(controlData.dualChannel == true) then
			if(controlData.getLeft ~= nil) then
				slider:SetLeftValue(controlData.translateToInterface(controlData.getLeft(component)))
				if(controlData.getLeftProperty ~= nil) then
					local prop = controlData.getLeftProperty(component)
					if(prop ~= nil) then
						local cb = prop:AddChangeListener(function(newValue)
							self:TagRenderSceneAsDirty()
							if(skipCallbacks) then return end
							skipCallbacks = true
							slider:SetLeftValue(controlData.translateToInterface(newValue))
							skipCallbacks = nil
						end)
						table.insert(callbacks,cb)
					end
				end
			end
			if(controlData.getRight ~= nil) then
				slider:SetRightValue(controlData.translateToInterface(controlData.getRight(component)))
				if(controlData.getRightProperty ~= nil) then
					local prop = controlData.getRightProperty(component)
					if(prop ~= nil) then
						local cb = prop:AddChangeListener(function(newValue)
							self:TagRenderSceneAsDirty()
							if(skipCallbacks) then return end
							skipCallbacks = true
							slider:SetRightValue(controlData.translateToInterface(newValue))
							skipCallbacks = nil
						end)
						table.insert(callbacks,cb)
					end
				end
			end
		end
	elseif(controlData.property ~= nil) then
		local prop = component:GetProperty(controlData.property)
		if(prop ~= nil) then
			local function get_numeric_value(val)
				if(val == true) then val = 1.0
				elseif(val == false) then val = 0.0 end
				return val
			end
			local cb = prop:AddChangeListener(function(newValue)
				self:TagRenderSceneAsDirty()
				if(skipCallbacks) then return end
				skipCallbacks = true
				slider:SetValue(controlData.translateToInterface(get_numeric_value(newValue)))
				skipCallbacks = nil
			end)
			table.insert(callbacks,cb)
			slider:SetValue(controlData.translateToInterface(get_numeric_value(prop:GetValue())))
		end
	end
	if(#callbacks > 0) then
		slider:AddCallback("OnRemove",function()
			for _,cb in ipairs(callbacks) do
				if(cb:IsValid()) then cb:Remove() end
			end
		end)
	end
	slider:AddCallback("OnLeftValueChanged",function(el,value)
		if(self.m_skipUpdateCallback) then return end
		if(controlData.boolean) then value = toboolean(value) end
		if(controlData.set ~= nil) then controlData.set(component,value) end
		--[[if(controlData.property ~= nil) then
			component:GetProperty(controlData.property):SetValue(controlData.translateFromInterface(value))
		elseif(controlData.set ~= nil) then
			controlData.set(component,value)
		elseif(controlData.setLeft ~= nil) then
			controlData.setLeft(component,value)
		end
		applyComponentChannelValue(self,component,controlData,value)]]
	end)
	slider:AddCallback("OnRightValueChanged",function(el,value)
		if(self.m_skipUpdateCallback) then return end
		if(controlData.boolean) then value = toboolean(value) end
		if(controlData.setRight ~= nil) then
			controlData.setRight(component,value)
		end
	end)
	--[[slider:AddCallback("PopulateContextMenu",function(el,pContext)
		pContext:AddItem("LOC: Set Math Expression",function()
			local parent = component:GetSceneParent()
			if(parent ~= nil and controlData.path ~= nil and parent:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR) then
				local channel = self:GetAnimationChannel(parent,controlData.path,true)
				if(channel ~= nil) then
					local expr = "abs(sin(time)) *20"
					debug.print("Set expression: ",expr)
					channel:SetExpression(expr)
					tool.get_filmmaker():GetAnimationManager():SetValueExpression(parent,controlData.path,expr)
				end
			end
		end)
		pContext:AddItem("LOC: Set Animation driver",function()
			local parent = component:GetSceneParent()
			if(parent ~= nil and controlData.path ~= nil and parent:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR) then
				local channel = self:GetAnimationChannel(parent,controlData.path,true)
				if(channel ~= nil) then
					--debug.print("Set expression!")
					--channel:SetExpression("sin(value)")
				end
			end
		end)
	end)]]
	table.insert(self.m_sliderControls,slider)
	return slider
end
function gui.PFMActorEditor:GetTimelineMode()
	local timeline = tool.get_filmmaker():GetTimeline()
	if(util.is_valid(timeline) == false) then return gui.PFMTimeline.EDITOR_CLIP end
	return timeline:GetEditor()
end
function gui.PFMActorEditor:GetAnimationChannel(actor,path,addIfNotExists)
	local filmClip = self:GetFilmClip()
	local track = filmClip:FindAnimationChannelTrack()
	
	local channelClip = track:FindActorAnimationClip(actor,addIfNotExists)
	if(channelClip == nil) then return end
	local path = panima.Channel.Path(path)
	local componentName,memberName = ents.PanimaComponent.parse_component_channel_path(path)
	local componentId = componentName and ents.get_component_id(componentName)
	local componentInfo = componentId and ents.get_component_info(componentId)

	local entActor = actor:FindEntity()
	local memberInfo
	if(memberName ~= nil and componentInfo ~= nil) then
		if(util.is_valid(entActor)) then
			local c = entActor:GetComponent(componentId)
			if(c ~= nil) then
				local memberId = c:GetMemberIndex(memberName:GetString())
				if(memberId ~= nil) then memberInfo = c:GetMemberInfo(memberId) end
			end
		end
		memberInfo = memberInfo or componentInfo:GetMemberInfo(memberName:GetString())
	end
	if(memberInfo == nil) then return end

	local type = memberInfo.type
	path = path:ToUri(false)
	local varType = fudm.udm_type_to_var_type(type)
	if(memberName:GetString() == "color") then varType = util.VAR_TYPE_COLOR end -- TODO: How to handle this properly?
	local channel = channelClip:GetChannel(path,varType,addIfNotExists)
	return channel,channelClip
end
function gui.PFMActorEditor:GetMemberInfo(actor,path)
	local path = panima.Channel.Path(path)
	local componentName,memberName = ents.PanimaComponent.parse_component_channel_path(path)
	local componentId = componentName and ents.get_component_id(componentName)
	local componentInfo = componentId and ents.get_component_info(componentId)
	if(memberName == nil or componentInfo == nil) then return end

	local entActor = actor:FindEntity()
	if(util.is_valid(entActor)) then
		local c = entActor:GetComponent(componentId)
		if(c ~= nil) then
			local memberId = c:GetMemberIndex(memberName:GetString())
			if(memberId ~= nil) then return c:GetMemberInfo(memberId) end
		end
	end
	return componentInfo:GetMemberInfo(memberName:GetString())
end
function gui.PFMActorEditor:SetAnimationChannelValue(actor,path,value,baseIndex)
	local fm = tool.get_filmmaker()
	local timeline = fm:GetTimeline()
	if(util.is_valid(timeline) and timeline:GetEditor() == gui.PFMTimeline.EDITOR_GRAPH) then
		local filmClip = self:GetFilmClip()
		local track = filmClip:FindAnimationChannelTrack()
		
		local animManager = fm:GetAnimationManager()
		local channelClip = track:FindActorAnimationClip(actor,true)
		local path = panima.Channel.Path(path)
		local componentName,memberName = ents.PanimaComponent.parse_component_channel_path(path)
		local componentId = componentName and ents.get_component_id(componentName)
		local componentInfo = componentId and ents.get_component_info(componentId)

		local entActor = actor:FindEntity()
		local memberInfo
		if(memberName ~= nil and componentInfo ~= nil) then
			if(util.is_valid(entActor)) then
				local c = entActor:GetComponent(componentId)
				if(c ~= nil) then
					local memberId = c:GetMemberIndex(memberName:GetString())
					if(memberId ~= nil) then memberInfo = c:GetMemberInfo(memberId) end
				end
			end
			memberInfo = memberInfo or componentInfo:GetMemberInfo(memberName:GetString())
		end
		if(memberInfo ~= nil) then
			local type = memberInfo.type
			path = path:ToUri(false)

			local time = fm:GetTimeOffset()
			local localTime = channelClip:LocalizeOffsetAbs(time)
			local anim = channelClip:GetPanimaAnimation()
			local channelValue = value
			if(util.get_type_name(channelValue) == "Color") then channelValue = channelValue:ToVector() end
			if(baseIndex ~= nil) then
				fm:SetActorAnimationComponentProperty(actor,path,localTime,channelValue,type,baseIndex)
			else
				fm:SetActorAnimationComponentProperty(actor,path,localTime,channelValue,type)
			end
		else
			local baseMsg = "Unable to apply animation channel value with channel path '" .. path.path:GetString() .. "': "
			if(componentName == nil) then pfm.log(baseMsg .. "Unable to determine component type from animation channel path '" .. path .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
			elseif(componentId == nil) then pfm.log(baseMsg .. "Component '" .. componentName .. "' is unknown!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
			else pfm.log(baseMsg .. "Component '" .. componentName .. "' has no known member '" .. memberName:GetString() .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING) end
		end
	end
end
function gui.PFMActorEditor:ScheduleUpdateSelectedEntities()
	if(self.m_updateSelectedEntities) then return end
	self:EnableThinking()
	self.m_updateSelectedEntities = true
end
function gui.PFMActorEditor:GetSelectedActors()
	local actors = {}
	for _,el in ipairs(self.m_tree:GetRoot():GetItems()) do
		if(el:IsSelected()) then
			local actorData = self.m_treeElementToActorData[el]
			if(actorData ~= nil) then
				table.insert(actors,actorData.actor)
			end
		end
	end
	return actors
end
function gui.PFMActorEditor:UpdateSelectedEntities()
	if(util.is_valid(self.m_tree) == false) then return end
	local selectionManager = tool.get_filmmaker():GetSelectionManager()
	selectionManager:ClearSelections()
	local function iterate_tree(el,level)
		if(util.is_valid(el) == false) then return false end
		level = level or 0
		local selected = el:IsSelected()
		if(selected == false) then
			for _,item in ipairs(el:GetItems()) do
				selected = iterate_tree(item,level +1)
				if(selected == true and level > 0) then break end
			end
		end
		if(selected and level == 1) then
			-- Root element or one of its children is selected; Select entity associated with the actor
			local actorData = self.m_treeElementToActorData[el]
			local ent = actorData.actor:FindEntity()
			if(ent ~= nil) then
				selectionManager:Select(ent)
			end
		end
		return selected
	end
	iterate_tree(self.m_tree:GetRoot())
end
function gui.PFMActorEditor:OnThink()
	if(self.m_updateSelectedEntities) then
		self.m_updateSelectedEntities = nil
		self:DisableThinking()
		self:UpdateSelectedEntities()
	end
end
function gui.PFMActorEditor:GetFilmClip() return self.m_filmClip end
function gui.PFMActorEditor:SelectActor(actor)
	if(util.is_valid(self.m_tree)) then self.m_tree:DeselectAll() end
	for itemActor,actorData in pairs(self.m_treeElementToActorData) do
		if(util.is_same_object(actor,actorData.actor)) then
			if(itemActor:IsValid()) then itemActor:Select() end
			break
		end
	end
end
function gui.PFMActorEditor:SetActorDirty(uniqueId)
	if(type(uniqueId) ~= "string") then uniqueId = tostring(uniqueId) end
	self.m_dirtyActorEntries = self.m_dirtyActorEntries or {}
	self.m_dirtyActorEntries[uniqueId] = true
end
function gui.PFMActorEditor:UpdateActorComponentEntries(actorData)
	self:SetActorDirty(tostring(actorData.actor:GetUniqueId()))
	local entActor = actorData.actor:FindEntity()
	if(entActor ~= nil) then self:InitializeDirtyActorComponents(tostring(actorData.actor:GetUniqueId()),entActor) end
end
function gui.PFMActorEditor:RemoveActorComponentEntry(uniqueId,componentId)
	if(type(uniqueId) ~= "string") then uniqueId = tostring(uniqueId) end
	local itemActor = self.m_actorUniqueIdToTreeElement[uniqueId]
	if(util.is_valid(itemActor) == false) then return end
	local actorData = self.m_treeElementToActorData[itemActor]
	if(actorData.componentData[componentId] == nil) then return end
	util.remove(actorData.componentData[componentId].items)
	util.remove(actorData.componentData[componentId].actionItems)
	util.remove(actorData.componentData[componentId].itemComponent)
	actorData.componentData[componentId] = nil
end
function gui.PFMActorEditor:InitializeDirtyActorComponents(uniqueId,entActor)
	if(type(uniqueId) ~= "string") then uniqueId = tostring(uniqueId) end
	if(self.m_dirtyActorEntries == nil or self.m_dirtyActorEntries[uniqueId] == nil) then return end
	entActor = entActor or ents.find_by_uuid(uniqueId)
	if(util.is_valid(entActor) == false) then return end
	self.m_dirtyActorEntries[uniqueId] = nil

	local itemActor = self.m_actorUniqueIdToTreeElement[uniqueId]
	if(util.is_valid(itemActor) == false) then return end
	local actorData = self.m_treeElementToActorData[itemActor]
	for _,component in ipairs(actorData.actor:GetComponents()) do
		local componentName = component:GetType()
		local componentId = ents.find_component_id(componentName)
		if(componentId == nil) then
			include_component(componentName)
			componentId = ents.find_component_id(componentName)
		end
		if(componentId ~= nil) then
			if(actorData.componentData[componentId] == nil) then
				self:AddActorComponent(entActor,actorData.itemActor,actorData,component)
			end
		else
			debug.print("Unknown component " .. componentName)
		end
	end
	actorData.componentsEntry:Update()
end
function gui.PFMActorEditor:OnActorPropertyChanged(entActor)
	local pm = pfm.get_project_manager()
	local vp = util.is_valid(pm) and pm:GetViewport() or nil
	local rt = util.is_valid(vp) and vp:GetRealtimeRaytracedViewport() or nil
	if(rt == nil) then return end
	rt:MarkActorAsDirty(entActor)
end
function gui.PFMActorEditor:AddActorComponent(entActor,itemActor,actorData,component)
	local componentType = component:GetType()
	local componentId = ents.find_component_id(componentType)
	if(componentId == nil) then return end
	actorData.componentData[componentId] = actorData.componentData[componentId] or {
		items = {},
		actionItems = {},
		actionData = {}
	}
	local componentData = actorData.componentData[componentId]
	local itemComponent = actorData.componentsEntry:AddItem(componentType,nil,nil,componentType)
	actorData.componentData[componentId].itemComponent = itemComponent
	local uniqueId = entActor:GetUuid()
	itemComponent:AddCallback("OnMouseEvent",function(tex,button,state,mods)
		if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
			local pContext = gui.open_context_menu()
			if(util.is_valid(pContext) == false) then return end
			pContext:SetPos(input.get_cursor_pos())

			pContext:AddItem(locale.get_text("remove"),function()
				local filmmaker = tool.get_filmmaker()
				local filmClip = filmmaker:GetActiveFilmClip()
				if(filmClip == nil) then return end
				local actor = filmClip:FindActorByUniqueId(uniqueId)
				if(actor == nil) then return end
				filmClip:RemoveActorComponent(actor,componentType)
				if(util.is_valid(itemComponent)) then
					local itemParent = itemComponent:GetParentItem()
					if(util.is_valid(itemParent)) then itemParent:RemoveItem(itemComponent) end
				end
				self:UpdateActorComponentEntries(actorData)
				local entActor = ents.find_by_uuid(uniqueId)
				if(util.is_valid(entActor)) then
					entActor:RemoveComponent(componentType)
					self:OnActorPropertyChanged(entActor)
				end
				self:TagRenderSceneAsDirty()
			end)
			pContext:Update()
			return util.EVENT_REPLY_HANDLED
		end
	end)
	itemComponent:AddCallback("OnSelectionChanged",function(el,selected)
		if(selected) then
			local actions = pfm.get_component_actions(componentType)
			if(actions ~= nil) then
				for id,action in pairs(actions) do
					actorData.componentData[componentId].actionData[id] = {}
					local entActor = ents.find_by_uuid(uniqueId)
					if(util.is_valid(entActor)) then
						local el = action.initialize(self.m_animSetControls,actorData.actor,entActor,actorData.componentData[componentId].actionData[id])
						if(util.is_valid(el)) then
							table.insert(actorData.componentData[componentId].actionItems,el)
						end
					end
				end
			end
		else util.remove(actorData.componentData[componentId].actionItems) end
	end)
	if(component.GetIconMaterial) then
		itemComponent:AddIcon(component:GetIconMaterial())
		itemActor:AddIcon(component:GetIconMaterial())
	end

	if(util.is_valid(componentData.itemBaseProps) == false) then
		componentData.itemBaseProps = itemComponent:AddItem(locale.get_text("pfm_base_properties"))
	end
	local componentInfo = (componentId ~= nil) and ents.get_component_info(componentId) or nil
	if(componentInfo ~= nil) then
		local uniqueId = entActor:GetUuid()
		local c = entActor:GetComponent(componentId)
		local function initializeProperty(info,controlData)
			controlData.integer = udm.is_integral_type(info.type)
			if(info:IsEnum()) then
				controlData.enum = true
				controlData.enumValues = {}
				for _,v in ipairs(info:GetEnumValues()) do
					table.insert(controlData.enumValues,{v,info:ValueToEnumName(v)})
				end
			end
			local val = component:GetMemberValue(info.name)
			if(val ~= nil) then
				c:SetMemberValue(info.name,val)
				return true
			end
			local valid = true
			if(info.type == udm.TYPE_STRING) then

			elseif(info.type == udm.TYPE_UINT8) then
				controlData.integer = true
			elseif(info.type == udm.TYPE_INT32) then
				controlData.integer = true
			elseif(info.type == udm.TYPE_UINT32) then
				controlData.integer = true
			elseif(info.type == udm.TYPE_UINT64) then
				controlData.integer = true
			elseif(info.type == udm.TYPE_FLOAT) then
			elseif(info.type == udm.TYPE_BOOLEAN) then
				controlData.boolean = true
			elseif(info.type == udm.TYPE_VECTOR2) then
				valid = false
			elseif(info.type == udm.TYPE_VECTOR3) then
				if(info.specializationType ~= ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_COLOR) then
					-- valid = false
				end
			elseif(info.type == udm.TYPE_VECTOR4) then
				valid = false
			elseif(info.type == udm.TYPE_QUATERNION) then
				-- valid = false
			elseif(info.type == udm.TYPE_EULER_ANGLES) then
			--elseif(info.type == udm.TYPE_INT8) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_INT16) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_UINT16) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_INT64) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_DOUBLE) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_VECTOR2I) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_VECTOR3I) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_VECTOR4I) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_SRGBA) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_HDR_COLOR) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_TRANSFORM) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_SCALED_TRANSFORM) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_MAT4) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_MAT3X4) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_BLOB) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_BLOB_LZ4) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_ELEMENT) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_ARRAY) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_ARRAY_LZ4) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_REFERENCE) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_STRUCT) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_HALF) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_UTF8_STRING) then props:SetProperty(info.name,udm.(info.default))
			--elseif(info.type == udm.TYPE_NIL) then props:SetProperty(info.name,udm.(info.default))
			else
				pfm.log("Unsupported component member type " .. info.type .. "!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
				valid = false
			end
			return valid
		end

		local function getMemberInfo(c,name)
			local idx = c:GetMemberIndex(name)
			if(idx == nil) then return end
			return c:GetMemberInfo(idx)
		end

		local function initializeMembers(memberIndices)
			for _,memberIdx in ipairs(memberIndices) do
				local memberInfo = c:GetMemberInfo(memberIdx)
				assert(memberInfo ~= nil)
				local controlData = {}
				local info = memberInfo
				local memberName = info.name
				local path = "ec/" .. componentInfo.name .. "/" .. info.name
				local valid = initializeProperty(info,controlData)
				if(valid) then
					controlData.name = info.name
					controlData.default = info.default
					controlData.path = path
					controlData.getValue = function()
						if(util.is_valid(c) == false) then
							if(util.is_valid(entActor) == false) then entActor = ents.find_by_uuid(uniqueId) end
							if(util.is_valid(entActor) == false) then
								console.print_warning("No actor with UUID '" .. uniqueId .. "' found!")
								return
							end
							c = entActor:GetComponent(componentId)
							if(util.is_valid(c) == false) then
								console.print_warning("No component " .. componentId .. " found in actor with UUID '" .. uniqueId .. "'!")
								return
							end
						end
						return c:GetMemberValue(memberName)
					end
					controlData.getMemberInfo = function()
						if(util.is_valid(c) == false) then
							if(util.is_valid(entActor) == false) then entActor = ents.find_by_uuid(uniqueId) end
							if(util.is_valid(entActor) == false) then
								console.print_warning("No actor with UUID '" .. uniqueId .. "' found!")
								return
							end
							c = entActor:GetComponent(componentId)
							if(util.is_valid(c) == false) then
								console.print_warning("No component " .. componentId .. " found in actor with UUID '" .. uniqueId .. "'!")
								return
							end
						end
						local idx = c:GetMemberIndex(memberName)
						if(idx == nil) then return end
						return c:GetMemberInfo(idx)
					end
					local value = controlData.getValue()
					if(udm.is_numeric_type(info.type) and info.type ~= udm.TYPE_BOOLEAN) then
						local min = info.min or 0
						local max = info.max or 100
						min = math.min(min,controlData.default or min,value or min)
						max = math.max(max,controlData.default or max,value or max)
						if(min == max) then max = max +100 end
						controlData.min = min
						controlData.max = max
					end
					pfm.log("Adding control for member '" .. controlData.path .. "' with type = " .. memberInfo.type .. ", min = " .. (tostring(controlData.min) or "nil") .. ", max = " .. (tostring(controlData.max) or "nil") .. ", default = " .. (tostring(controlData.default) or "nil") .. ", value = " .. (tostring(value) or "nil") .. "...",pfm.LOG_CATEGORY_PFM)
					controlData.set = function(component,value,dontTranslateValue,updateAnimationValue)
						if(updateAnimationValue == nil) then updateAnimationValue = true end
						local entActor = ents.find_by_uuid(uniqueId)
						local c = (entActor ~= nil) and entActor:GetComponent(componentId) or nil
						local memberIdx = (c ~= nil) and c:GetMemberIndex(controlData.name) or nil
						local info = (memberIdx ~= nil) and c:GetMemberInfo(memberIdx) or nil
						if(info == nil) then return end
						if(dontTranslateValue ~= true) then value = controlData.translateFromInterface(value) end
						local memberValue = value
						if(util.get_type_name(memberValue) == "Color") then memberValue = memberValue:ToVector() end

						component:SetMemberValue(memberName,info.type,memberValue)
						
						local entActor = actorData.actor:FindEntity()
						if(entActor ~= nil) then
							local c = entActor:GetComponent(componentId)
							if(c ~= nil) then
								c:SetMemberValue(memberName,memberValue)
								self:OnActorPropertyChanged(entActor)
							end
						end
						if(updateAnimationValue) then applyComponentChannelValue(self,component,controlData,memberValue) end
						self:TagRenderSceneAsDirty()
					end
					controlData.set(component,value,true,false)
					actorData.componentData[componentId].items[memberIdx] = self:AddControl(entActor,c,actorData,componentData,component,itemComponent,controlData,path)
				else
					pfm.log("Unable to add control for member '" .. path .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
				end
			end
		end
		-- Static members have to be initialized first, because dynamic members may be dependent on static members
		local staticMemberIndices = {}
		for i=0,c:GetStaticMemberCount() -1 do
			table.insert(staticMemberIndices,i)
		end
		initializeMembers(staticMemberIndices)

		-- Initialize dynamic members next. Dynamic members must not have any dependencies to other dynamic members
		initializeMembers(c:GetDynamicMemberIndices())
	end
end
function gui.PFMActorEditor:CopyToClipboard(actors)
	actors = actors or self:GetSelectedActors()
	local el = udm.create_element()
	local pfmCopy = el:Add("pfm_copy")

	local filmClip = self:GetFilmClip()
	local track = filmClip:FindAnimationChannelTrack()
	local animationData = {}
	for _,actor in ipairs(actors) do
		local channelClip = track:FindActorAnimationClip(actor)
		if(channelClip ~= nil) then
			table.insert(animationData,channelClip:GetUdmData())
		end
	end
	pfmCopy:AddArray("data",#actors +#animationData,udm.TYPE_ELEMENT)
	local data = pfmCopy:Get("data")
	for i,actor in ipairs(actors) do
		local udmData = data:Get(i -1)
		udmData:SetValue("type",udm.TYPE_STRING,"actor")
		udmData:Add("data"):Merge(actor:GetUdmData())
	end
	local offset = #actors
	for i,animData in ipairs(animationData) do
		local udmData = data:Get(offset +i -1)
		udmData:SetValue("type",udm.TYPE_STRING,"animation")
		udmData:Add("data"):Merge(animData)
	end
	util.set_clipboard_string(el:ToAscii(udm.ASCII_SAVE_FLAG_NONE))
end
function gui.PFMActorEditor:PasteFromClipboard()
	local res,err = udm.parse(util.get_clipboard_string())
	if(res == false) then
		console.print_warning("Failed to parse UDM: ",err)
		return
	end
	local data = res:GetAssetData():GetData()
	local pfmCopy = data:Get("pfm_copy")
	local data = pfmCopy:Get("data")
	if(data:IsValid() == false) then
		console.print_warning("No copy data found in clipboard UDM string!")
		return
	end
	local filmClip = self:GetFilmClip()
	local track = filmClip:FindAnimationChannelTrack()

	-- Assign new unique ids to prevent id collisions
	local oldIdToNewId = {}
	local function iterate_elements(udmData,f)
		f(udmData)

		for _,udmChild in pairs(udmData:GetChildren()) do
			iterate_elements(udmChild,f)
		end

		if(udm.is_array_type(udmData:GetType()) and udmData:GetValueType() == udm.TYPE_ELEMENT) then
			local n = udmData:GetSize()
			for i=1,n do
				iterate_elements(udmData:Get(i -1),f)
			end
		end
	end
	iterate_elements(data,function(udmData)
		if(udmData:HasValue("uniqueId")) then
			local oldUniqueId = udmData:GetValue("uniqueId",udm.TYPE_STRING)
			local newUniqueId = tostring(util.generate_uuid_v4())
			udmData:SetValue("uniqueId",udm.TYPE_STRING,newUniqueId)
			oldIdToNewId[oldUniqueId] = newUniqueId
		end
	end)
	iterate_elements(data,function(udmData)
		for name,udmChild in pairs(udmData:GetChildren()) do
			if(udmChild:GetType() == udm.TYPE_STRING) then
				local val = udmData:GetValue(name,udm.TYPE_STRING)
				if(oldIdToNewId[val] ~= nil) then
					udmData:SetValue(name,udm.TYPE_STRING,oldIdToNewId[val])
				end
			end
		end
	end)
	--

	local n = data:GetSize()
	for i=1,n do
		local udmData = data:Get(i -1)
		local type = udmData:GetValue("type",udm.TYPE_STRING)
		if(type == "actor") then
			local actor = self:CreateNewActor()
			actor:Reinitialize(udmData:Get("data"))
		elseif(type == "animation") then
			local animData = udmData:Get("data")
			local actorUniqueId = animData:GetValue("actor",udm.TYPE_STRING)
			local actor = filmClip:FindActorByUniqueId(actorUniqueId)
			if(actor == nil) then console.print_warning("Animation data refers to unknown actor with unique id " .. actorUniqueId .. "! Ignoring...")
			else
				local channelClip = track:FindActorAnimationClip(actor,true)
				channelClip:Reinitialize(animData)
			end
		else
			console.print_warning("Copy type " .. type .. " is not compatible!")
		end
	end

	tool.get_filmmaker():ReloadGameView()
	self:Reload()
end
function gui.PFMActorEditor:MouseCallback(button,state,mods)
	if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
		local pContext = gui.open_context_menu()
		if(util.is_valid(pContext) == false) then return end
		pContext:SetPos(input.get_cursor_pos())

		pContext:AddItem(locale.get_text("pfm_copy_actors"),function() self:CopyToClipboard() end)
		pContext:AddItem(locale.get_text("pfm_paste_actors"),function() self:PasteFromClipboard() end)
		pContext:Update()
		return util.EVENT_REPLY_HANDLED
	end
end
function gui.PFMActorEditor:AddActor(actor)
	local itemActor = self.m_tree:AddItem(actor:GetName())

	local uniqueId = tostring(actor:GetUniqueId())
	itemActor:AddCallback("OnSelectionChanged",function(el,selected)
		local entActor = actor:FindEntity()
		if(util.is_valid(entActor)) then
			local pfmActorC = entActor:GetComponent(ents.COMPONENT_PFM_ACTOR)
			if(pfmActorC ~= nil) then
				pfmActorC:SetSelected(selected)
			end
		end
	end)	
	itemActor:AddCallback("OnMouseEvent",function(el,button,state,mods)
		if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
			local pContext = gui.open_context_menu()
			if(util.is_valid(pContext) == false) then return end
			pContext:SetPos(input.get_cursor_pos())

			pContext:AddItem(locale.get_text("pfm_export_animation"),function()
				local entActor = actor:FindEntity()
				if(util.is_valid(entActor) == false) then return end
				local filmmaker = tool.get_filmmaker()
				filmmaker:ExportAnimation(entActor)
			end)
			pContext:AddItem(locale.get_text("pfm_copy_actors"),function() self:CopyToClipboard() end)
			pContext:AddItem(locale.get_text("pfm_paste_actors"),function() self:PasteFromClipboard() end)
			pContext:AddItem(locale.get_text("pfm_move_work_camera_to_actor"),function()
				local filmmaker = tool.get_filmmaker()
				local filmClip = filmmaker:GetActiveFilmClip()
				if(filmClip == nil) then return end
				local actor = filmClip:FindActorByUniqueId(uniqueId)
				if(actor == nil) then return end
				local pm = pfm.get_project_manager()
				local vp = util.is_valid(pm) and pm:GetViewport() or nil
				if(util.is_valid(vp) == false) then return end
				vp:SetWorkCameraPose(actor:GetAbsolutePose())
			end)
			pContext:AddItem(locale.get_text("pfm_toggle_camera_link"),function()
				local filmmaker = tool.get_filmmaker()
				local entActor = actor:FindEntity()
				local vp = filmmaker:GetViewport()
				if(util.is_valid(vp) == false or util.is_valid(entActor) == false) then return end
				local cam = vp:GetCamera()
				if(util.is_valid(cam) == false) then return end
				local ent = cam:GetEntity()
				if(ent:HasComponent("pfm_camera_actor_link")) then
					ent:RemoveComponent("pfm_camera_actor_link")
					if(self.m_camLinkOrigFov ~= nil) then
						cam:SetFOV(self.m_camLinkOrigFov)
						self.m_camLinkOrigFov = nil
					end
					if(self.m_camLinkOrigPose ~= nil) then
						vp:SetWorkCameraPose(self.m_camLinkOrigPose)
						self.m_camLinkOrigPose = nil
					end
					self:TagRenderSceneAsDirty()
				else
					local c = cam:GetEntity():AddComponent("pfm_camera_actor_link")
					if(c ~= nil) then
						c:SetTargetActor(entActor)
						local lightSpotC = entActor:GetComponent(ents.COMPONENT_LIGHT_SPOT)
						if(lightSpotC ~= nil) then
							self.m_camLinkOrigFov = cam:GetFOV()
							self.m_camLinkOrigPose = cam:GetEntity():GetPose()
							cam:SetFOV(lightSpotC:GetOuterConeAngle())
						end
						local camC = entActor:GetComponent(ents.COMPONENT_CAMERA)
						if(camC ~= nil) then
							cam:SetFOV(camC:GetFOV())
						end
						vp:SetWorkCameraPose(entActor:GetPose())
						self:TagRenderSceneAsDirty()
					end
				end
			end)
			pContext:AddItem(locale.get_text("rename"),function()
				local te = gui.create("WITextEntry",itemActor,0,0,itemActor:GetWidth(),itemActor:GetHeight(),0,0,1,1)
				te:SetText(actor:GetName())
				te:RequestFocus()
				te:AddCallback("OnFocusKilled",function()
					actor:SetName(te:GetText())
					itemActor:SetText(te:GetText())
					te:RemoveSafely()
				end)
			end)
			pContext:AddItem(locale.get_text("remove"),function()
				local filmmaker = tool.get_filmmaker()
				local filmClip = filmmaker:GetActiveFilmClip()
				if(filmClip == nil) then return end
				local actor = filmClip:FindActorByUniqueId(uniqueId)
				if(actor == nil) then return end
				filmClip:RemoveActor(actor)
				self.m_tree:RemoveItem(itemActor)

				util.remove(ents.find_by_uuid(uniqueId))
				self:TagRenderSceneAsDirty()
			end)
			pContext:Update()
			return util.EVENT_REPLY_HANDLED
		end
	end)

	local itemComponents = itemActor:AddItem(locale.get_text("components"))
	self.m_treeElementToActorData[itemActor] = {
		actor = actor,
		itemActor = itemActor,
		componentsEntry = itemComponents,
		componentData = {}
	}
	self.m_actorUniqueIdToTreeElement[tostring(actor:GetUniqueId())] = itemActor
	itemComponents:AddCallback("OnMouseEvent",function(tex,button,state,mods)
		if(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
			local pContext = gui.open_context_menu()
			if(util.is_valid(pContext) == false) then return end
			pContext:SetPos(input.get_cursor_pos())

			local entActor = actor:FindEntity()
			if(util.is_valid(entActor)) then
				local existingComponents = {}
				local newComponentMap = {}
				for _,componentId in ipairs(ents.get_registered_component_types()) do
					local info = ents.get_component_info(componentId)
					local name = info.name
					if(actor:HasComponent(name) == false) then
						if(entActor:HasComponent(name)) then table.insert(existingComponents,name)
						else newComponentMap[name] = true end
					end
				end
				for _,name in ipairs(ents.find_installed_custom_components()) do
					newComponentMap[name] = true
				end
				local newComponents = {}
				for name,_ in pairs(newComponentMap) do
					table.insert(newComponents,name)
				end
				if(#existingComponents > 0) then
					local pComponentsItem,pComponentsMenu = pContext:AddSubMenu(locale.get_text("pfm_add_component"))
					table.sort(existingComponents)
					for _,name in ipairs(existingComponents) do
						local displayName = name
						local valid,n = locale.get_text("component_" .. name,nil,true)
						if(valid) then displayName = n end
						pComponentsMenu:AddItem(displayName,function()
							self:CreateNewActorComponent(actor,name,true)
						end)
					end
					pComponentsMenu:Update()
				end
				if(#newComponents > 0) then
					local pComponentsItem,pComponentsMenu = pContext:AddSubMenu(locale.get_text("pfm_add_new_component"))
					table.sort(newComponents)
					for _,name in ipairs(newComponents) do
						local displayName = name
						local valid,n = locale.get_text("component_" .. name,nil,true)
						if(valid) then displayName = n end
						pComponentsMenu:AddItem(displayName,function()
							self:CreateNewActorComponent(actor,name,true)
						end)
					end
					pComponentsMenu:Update()
				end
			end
			pContext:Update()
			return util.EVENT_REPLY_HANDLED
		end
	end)
	self:UpdateActorComponentEntries(self.m_treeElementToActorData[itemActor])
end
function gui.PFMActorEditor:Reload()
	if(self.m_filmClip == nil) then return end
	self:Setup(self.m_filmClip)
end
function gui.PFMActorEditor:Setup(filmClip)
	-- if(util.is_same_object(filmClip,self.m_filmClip)) then return end
	self.m_filmClip = filmClip
	self.m_tree:Clear()
	self.m_treeElementToActorData = {}
	self.m_actorUniqueIdToTreeElement = {}
	-- TODO: Include groups the actors belong to!
	for _,actor in ipairs(filmClip:GetActorList()) do
		self:AddActor(actor)
	end
end
function gui.PFMActorEditor:AddProperty(name,child,fInitPropertyEl)
	--[[local elLabelContainer
	local elProperty
	local elHeight = 24
	child:AddCallback("OnSelected",function()
		print("OnSelected")
		elLabelContainer = gui.create("WIBase",self.m_propertiesLabelsVBox)
		elLabelContainer:SetHeight(elHeight)

		local elLabel = gui.create("WIText",elLabelContainer)
		elLabel:SetText(name)
		elLabel:SetColor(Color(200,200,200))
		elLabel:SetFont("pfm_medium")
		elLabel:SizeToContents()
		elLabel:CenterToParentY()
		elLabel:SetX(5)

		elProperty = fInitPropertyEl(self.m_propertiesElementsVBox)
		if(util.is_valid(elProperty)) then
			elProperty:SetHeight(elHeight)
			elProperty:AddCallback("OnRemove",function() util.remove(elLabelContainer) end)
		end
	end)
	local function cleanUp()
		util.remove(elLabelContainer,true)
		util.remove(elProperty,true)
	end
	child:AddCallback("OnDeselected",cleanUp)
	child:AddCallback("OnRemove",cleanUp)]]

	local elHeight = 24
	local elLabelContainer = gui.create("WIBase",self.m_propertiesLabelsVBox)
	elLabelContainer:SetHeight(elHeight)

	local elLabel = gui.create("WIText",elLabelContainer)
	elLabel:SetText(name)
	elLabel:SetColor(Color(200,200,200))
	elLabel:SetFont("pfm_medium")
	elLabel:SizeToContents()
	elLabel:CenterToParentY()
	elLabel:SetX(5)

	local elProperty = fInitPropertyEl(self.m_propertiesElementsVBox)
	if(util.is_valid(elProperty)) then
		elProperty:SetHeight(elHeight)
		elProperty:AddCallback("OnRemove",function() util.remove(elLabelContainer) end)
	end
	return elProperty
end
function gui.PFMActorEditor:GetActiveControls() return self.m_activeControls end
function gui.PFMActorEditor:UpdateActorProperty(actor,path)
	local uid = tostring(actor:GetUniqueId())
	if(self.m_activeControls[uid] == nil) then return end
	local t = self.m_activeControls[uid]
	if(t[path] == nil) then return end
	local ac = t[path]
	self:UpdateControlValue(ac.controlData)
end
function gui.PFMActorEditor:UpdateControlValue(controlData)
	if(controlData.updateControlValue == nil) then return end
	self.m_skipUpdateCallback = true
	controlData.updateControlValue()
	self.m_skipUpdateCallback = nil
end
function gui.PFMActorEditor:UpdateControlValues()
	for uid,t in pairs(self.m_activeControls) do
		for path,ac in pairs(t) do
			self:UpdateControlValue(ac.controlData)
		end
	end
end
function gui.PFMActorEditor:OnControlSelected(actor,actorData,udmComponent,controlData)
	local memberInfo = self:GetMemberInfo(actor,controlData.path)
	if(memberInfo == nil) then
		-- TODO: Members can become invalid if, for example, an actor's model has changed. In this case, the entire tree in the actor editor should be reloaded!
		console.print_warning("Attempted to access member info for property '" .. controlData.path .. "' for actor '" .. tostring(actor) .. "', but member is no longer valid!")
		return
	end

	local ctrl
	if(controlData.path ~= nil) then
		if(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_COLOR) then
			local colField,wrapper = self.m_animSetControls:AddColorField(memberInfo.name,memberInfo.name,(controlData.default and Color(controlData.default)) or Color.White,function(oldCol,newCol)
				if(self.m_skipUpdateCallback) then return end
				if(controlData.set ~= nil) then controlData.set(udmComponent,newCol) end
			end)
			if(controlData.getValue ~= nil) then
				controlData.updateControlValue = function()
					if(colField:IsValid() == false) then return end
					local val = controlData.getValue()
					if(val ~= nil) then colField:SetColor(Color(val)) end
				end
			end
			ctrl = wrapper
		elseif(memberInfo.type == udm.TYPE_STRING) then
			if(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_FILE) then
				local meta = memberInfo.metaData or udm.create_element()
				if(meta ~= nil) then
					if(meta:GetValue("assetType") == "model") then
						ctrl = self:AddProperty(memberInfo.name,child,function(parent)
							local el = gui.create("WIFileEntry",parent)
							if(controlData.getValue ~= nil) then
								controlData.updateControlValue = function()
									if(el:IsValid() == false) then return end
									local val = controlData.getValue()
									if(val ~= nil) then el:SetValue(val) end
								end
							end
							el:SetBrowseHandler(function(resultHandler)
								gui.open_model_dialog(function(dialogResult,mdlName)
									if(dialogResult ~= gui.DIALOG_RESULT_OK) then return end
									resultHandler(mdlName)
								end)
							end)
							el:AddCallback("OnValueChanged",function(el,value)
								if(self.m_skipUpdateCallback) then return end
								if(controlData.set ~= nil) then controlData.set(udmComponent,value) end
							end)
							return el
						end)
					end
				end
				if(util.is_valid(ctrl) == false) then
					ctrl = self:AddProperty(memberInfo.name,child,function(parent)
						local el = gui.create("WIFileEntry",parent)
						if(controlData.getValue ~= nil) then
							controlData.updateControlValue = function()
								if(el:IsValid() == false) then return end
								local val = controlData.getValue()
								if(val ~= nil) then el:SetValue(val) end
							end
						end
						el:SetBrowseHandler(function(resultHandler)
							local pFileDialog = gui.create_file_open_dialog(function(el,fileName)
								if(fileName == nil) then return end
								local basePath = meta:GetValue("basePath") or ""
								resultHandler(basePath .. el:GetFilePath(true))
							end)
							local rootPath = meta:GetValue("rootPath")
							if(rootPath ~= nil) then pFileDialog:SetRootPath(rootPath) end
							local extensions = meta:Get("extensions"):ToTable()
							if(#extensions > 0) then pFileDialog:SetExtensions(extensions) end
							pFileDialog:Update()
						end)
						el:AddCallback("OnValueChanged",function(el,value)
							if(self.m_skipUpdateCallback) then return end
							if(controlData.set ~= nil) then controlData.set(udmComponent,value) end
						end)
						return el
					end)
				end
			else
				local elText,wrapper = self.m_animSetControls:AddTextEntry(memberInfo.name,memberInfo.name,controlData.default or "",function(el)
					if(self.m_skipUpdateCallback) then return end
					if(controlData.set ~= nil) then controlData.set(udmComponent,el:GetText()) end
				end)
				if(controlData.getValue ~= nil) then
					controlData.updateControlValue = function()
						if(elText:IsValid() == false) then return end
						local val = controlData.getValue()
						if(val ~= nil) then elText:SetText(val) end
					end
				end
				ctrl = wrapper
			end
		elseif(memberInfo.type == udm.TYPE_BOOLEAN) then
			local elToggle,wrapper = self.m_animSetControls:AddToggleControl(memberInfo.name,memberInfo.name,controlData.default or false,function(oldChecked,checked)
				if(self.m_skipUpdateCallback) then return end
				if(controlData.set ~= nil) then controlData.set(udmComponent,checked) end
			end)
			if(controlData.getValue ~= nil) then
				controlData.updateControlValue = function()
					if(elToggle:IsValid() == false) then return end
					local val = controlData.getValue()
					if(val ~= nil) then elToggle:SetChecked(val) end
				end
			else elToggle:SetChecked(false) end
			ctrl = wrapper
		elseif(udm.is_numeric_type(memberInfo.type)) then
			if(memberInfo:IsEnum()) then
				local enumValues = {}
				local defaultValueIndex
				for i,v in ipairs(memberInfo:GetEnumValues()) do
					table.insert(enumValues,{tostring(v),memberInfo:ValueToEnumName(v)})
					if(v == memberInfo.default) then
						defaultValueIndex = i -1
					end
				end
				local el,wrapper = self.m_animSetControls:AddDropDownMenu(memberInfo.name,memberInfo.name,enumValues,tostring(defaultValueIndex),function(el)
					if(self.m_skipUpdateCallback) then return end
					if(controlData.set ~= nil) then controlData.set(udmComponent,tonumber(el:GetOptionValue(el:GetSelectedOption()))) end
				end)
				ctrl = wrapper
				controlData.updateControlValue = function()
					if(ctrl:IsValid() == false) then return end
					local val = controlData.getValue()
					if(val ~= nil) then
						local idx = el:FindOptionIndex(tostring(val))
						if(idx ~= nil) then el:SelectOption(idx)
						else el:SetText(tostring(val)) end
					end
				end
			else
				if(memberInfo.minValue ~= nil) then controlData.min = memberInfo.minValue end
				if(memberInfo.maxValue ~= nil) then controlData.max = memberInfo.maxValue end
				if(memberInfo.default ~= nil) then controlData.default = memberInfo.default end

				if(memberInfo.type == udm.TYPE_BOOLEAN) then
					controlData.min = controlData.min and 1 or 0
					controlData.max = controlData.max and 1 or 0
					controlData.default = controlData.default and 1 or 0
				end

				local channel = self:GetAnimationChannel(actorData.actor,controlData.path,false)
				local hasExpression = (channel ~= nil and channel:GetExpression() ~= nil)
				if(hasExpression == false) then
					if(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_DISTANCE) then
						controlData.unit = locale.get_text("symbol_meters")
						controlData.translateToInterface = function(val) return util.units_to_metres(val) end
						controlData.translateFromInterface = function(val) return util.metres_to_units(val) end
					elseif(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_LIGHT_INTENSITY) then
						-- TODO
						controlData.unit = locale.get_text("symbol_lumen")--(self:GetIntensityType() == ents.LightComponent.INTENSITY_TYPE_CANDELA) and locale.get_text("symbol_candela") or locale.get_text("symbol_lumen")
					end
				end
				ctrl = self:AddSliderControl(udmComponent,controlData)
				if(controlData.unit) then ctrl:SetUnit(controlData.unit) end

				controlData.updateControlValue = function()
					if(ctrl:IsValid() == false) then return end
					local val = controlData.getValue()
					if(val ~= nil) then ctrl:SetValue(val) end
				end

				-- pfm.log("Attempted to add control for member with path '" .. controlData.path .. "' of actor '" .. tostring(actor) .. "', but member type " .. tostring(memberInfo.specializationType) .. " is unknown!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
			end
		elseif(memberInfo.type == udm.TYPE_EULER_ANGLES) then
			local val = EulerAngles()
			local el,wrapper = self.m_animSetControls:AddTextEntry(memberInfo.name,memberInfo.name,tostring(val),function(el)
				if(self.m_skipUpdateCallback) then return end
				if(controlData.set ~= nil) then controlData.set(udmComponent,EulerAngles(el:GetText())) end
			end)
			if(controlData.getValue ~= nil) then
				controlData.updateControlValue = function()
					if(el:IsValid() == false) then return end
					local val = controlData.getValue() or EulerAngles()
					if(val ~= nil) then el:SetText(tostring(val)) end
				end
			end
			ctrl = wrapper
		elseif(memberInfo.type == udm.TYPE_QUATERNION) then
			local val = EulerAngles()
			local el,wrapper = self.m_animSetControls:AddTextEntry(memberInfo.name,memberInfo.name,tostring(val),function(el)
				if(self.m_skipUpdateCallback) then return end
				if(controlData.set ~= nil) then controlData.set(udmComponent,EulerAngles(el:GetText()):ToQuaternion()) end
			end)
			if(controlData.getValue ~= nil) then
				controlData.updateControlValue = function()
					if(el:IsValid() == false) then return end
					local val = controlData.getValue() or Quaternion()
					if(val ~= nil) then el:SetText(tostring(val:ToEulerAngles())) end
				end
			end
			ctrl = wrapper
		elseif(udm.is_vector_type(memberInfo.type) or udm.is_matrix_type(memberInfo.type)) then
			local type = udm.get_class_type(memberInfo.type)
			local val = type()
			if(controlData.getValue ~= nil) then val = controlData.getValue() or val end
			local el,wrapper = self.m_animSetControls:AddTextEntry(memberInfo.name,memberInfo.name,tostring(val),function(el)
				if(self.m_skipUpdateCallback) then return end
				if(controlData.set ~= nil) then controlData.set(udmComponent,type(el:GetText())) end
			end)
			if(controlData.getValue ~= nil) then
				controlData.updateControlValue = function()
					if(el:IsValid() == false) then return end
					local val = controlData.getValue() or type()
					if(val ~= nil) then el:SetText(tostring(val)) end
				end
			end
			ctrl = wrapper
		else return ctrl end
	end
	if(util.is_valid(ctrl) == false) then
		if(controlData.addControl) then
			ctrl = controlData.addControl(self.m_animSetControls,function(value)
				applyComponentChannelValue(self,udmComponent,controlData,value)
			end)
		else
			ctrl = self:AddSliderControl(udmComponent,controlData)
			if(controlData.unit) then ctrl:SetUnit(controlData.unit) end
		end
	end
	if(ctrl ~= nil) then
		local type = memberInfo.type
		local exprIcon
		local enable_expr_icon
		local function clear_expression()
			local pm = pfm.get_project_manager()
			local animManager = pm:GetAnimationManager()
			if(animManager == nil) then return end
			animManager:SetValueExpression(actorData.actor,controlData.path)

			local anim,channel,animClip = animManager:FindAnimationChannel(actorData.actor,controlData.path)
			if(animClip ~= nil) then
				local channel = animClip:GetChannel(controlData.path)
				if(channel ~= nil) then
					channel:SetExpression()
				end
			end
			enable_expr_icon(false)
		end
		local function set_expression()
			local pm = pfm.get_project_manager()
			local animManager = pm:GetAnimationManager()
			if(animManager == nil) then return end
			local te
			local p = pfm.open_entry_edit_window(locale.get_text("pfm_set_expression"),function(ok)
				if(ok) then
					local res = animManager:SetValueExpression(actorData.actor,controlData.path,te:GetText(),type)
					if(res) then
						local anim,channel,animClip = animManager:FindAnimationChannel(actorData.actor,controlData.path,true,type)
						if(animClip ~= nil) then
							local channel = animClip:GetChannel(controlData.path)
							if(channel ~= nil) then
								channel:SetExpression(te:GetText())
							end
						end
					else
						clear_expression()
					end
					enable_expr_icon(res)
				end
			end)
			local expr = animManager:GetValueExpression(actorData.actor,controlData.path)
			te = p:AddTextField(locale.get_text("pfm_expression") .. ":",expr or "")
			te:GetTextElement():SetFont("pfm_medium")

			p:SetWindowSize(Vector2i(800,120))
			p:Update()
		end
		enable_expr_icon = function(enabled)
			if(enabled == false) then
				util.remove(exprIcon)
				return
			end
			if(util.is_valid(exprIcon)) then return end
			local el = gui.create("WIRect",ctrl)
			el:SetSize(5,5)
			el:SetPos(ctrl:GetWidth() -7,2)
			el:SetColor(pfm.get_color_scheme_color("red"))
			el:SetAnchor(1,0,1,0)
			el:SetCursor(gui.CURSOR_SHAPE_HAND)
			el:SetMouseInputEnabled(true)
			el:AddCallback("OnMouseEvent",function(wrapper,button,state,mods)
				if(button == input.MOUSE_BUTTON_LEFT) then
					if(state == input.STATE_PRESS) then
						set_expression()
					end
					return util.EVENT_REPLY_HANDLED
				end
			end)
			exprIcon = el
		end
		local pm = pfm.get_project_manager()
		local animManager = pm:GetAnimationManager()
		if(animManager ~= nil and animManager:GetValueExpression(actorData.actor,controlData.path) ~= nil) then
			enable_expr_icon(true)
		end

		ctrl:AddCallback("PopulateContextMenu",function(ctrl,context)
			local pm = pfm.get_project_manager()
			local animManager = pm:GetAnimationManager()
			if(animManager ~= nil) then
				local expr = animManager:GetValueExpression(actorData.actor,controlData.path)
				if(expr ~= nil) then
					context:AddItem(locale.get_text("pfm_clear_expression"),function()
						clear_expression()
					end)
					context:AddItem(locale.get_text("pfm_copy_expression"),function() util.set_clipboard_string(expr) end)
				end
				context:AddItem(locale.get_text("pfm_set_expression"),set_expression)
				if(controlData.path ~= nil) then
					context:AddItem(locale.get_text("pfm_copy_property_path"),function()
						util.set_clipboard_string(controlData.path)
					end)
				end
				local anim,channel = animManager:FindAnimationChannel(actorData.actor,controlData.path,false)
				if(channel ~= nil) then
					context:AddItem(locale.get_text("pfm_clear_animation"),function()
						animManager:RemoveChannel(actorData.actor,controlData.path)
						local entActor = actorData.actor:FindEntity()
						if(util.is_valid(entActor) == false) then return end
						local actorC = entActor:GetComponent(ents.COMPONENT_PFM_ACTOR)
						if(actorC ~= nil) then
							actorC:ApplyComponentMemberValue(controlData.path)
						end

						local animC = entActor:GetComponent(ents.COMPONENT_PANIMA)
						if(animC ~= nil) then animC:ReloadAnimation() end
					end)
				end
			end
		end)
	end
	self:UpdateControlValue(controlData)
	self:CallCallbacks("OnControlSelected",actor,udmComponent,controlData,ctrl)
	return ctrl
end
function gui.PFMActorEditor:AddIkController(actor,boneName,chainLength,ikName)
	if(chainLength <= 1) then return false end

	local c = self:CreateNewActorComponent(actor,"pfm_ik",false)
	if(c == nil) then return false end

	local ent = actor:FindEntity()
	if(util.is_valid(ent) == false) then return false end
	local mdl = ent:GetModel()
	local skeleton = mdl:GetSkeleton()
	local boneId = mdl:LookupBone(boneName)
	if(boneId == -1) then return false end

	local pfmIk = util.is_valid(ent) and ent:AddComponent("pfm_ik") or nil
	if(pfmIk == nil) then return false end
	local bone = skeleton:GetBone(boneId)
	ikName = ikName or bone:GetName()

	self:UpdateActorComponents(actor)

	ent = actor:FindEntity()
	pfmIk = util.is_valid(ent) and ent:GetComponent("pfm_ik") or nil
	if(pfmIk ~= nil) then
		pfmIk:AddIkControllerByChain(boneName,chainLength,ikName)
		pfmIk:SaveConfig()
		pfmIk:InitializeFromConfiguration()
	end

	local componentId = ents.find_component_id("pfm_ik")
	if(componentId ~= nil) then
		self:RemoveActorComponentEntry(tostring(actor:GetUniqueId()),componentId)
		self:SetActorDirty(tostring(actor:GetUniqueId()))
		self:InitializeDirtyActorComponents(tostring(actor:GetUniqueId()))
	end

	return true
end
function gui.PFMActorEditor:AddControl(entActor,component,actorData,componentData,udmComponent,item,controlData,identifier)
	local actor = udmComponent:GetActor()
	local memberInfo = (actor ~= nil) and self:GetMemberInfo(actor,controlData.path) or nil
	if(memberInfo == nil) then return end
	controlData.translateToInterface = controlData.translateToInterface or function(val) return val end
	controlData.translateFromInterface = controlData.translateFromInterface or function(val) return val end

	local isBaseProperty = (memberInfo.type == udm.TYPE_STRING)
	local baseItem = isBaseProperty and componentData.itemBaseProps or item

	local componentName,memberName = ents.PanimaComponent.parse_component_channel_path(panima.Channel.Path(controlData.path))
	local isAnimatedComponent = (componentName == "animated")

	local memberComponents = string.split(memberName:GetString(),"/")
	local isBone = (#memberComponents >= 2 and memberComponents[1] == "bone")

	local propertyPathComponents = string.split(controlData.name,"/")
	for i=1,#propertyPathComponents -1 do
		local cname = propertyPathComponents[i]
		local cnameItem = baseItem:GetItemByIdentifier(cname)
		local childItem
		if(util.is_valid(cnameItem)) then childItem = cnameItem
		else childItem = baseItem:AddItem(cname,nil,nil,cname) end
		baseItem = childItem

		if(isBone and i == 2) then
			childItem.__boneMouseEvent = childItem.__boneMouseEvent or childItem:AddCallback("OnMouseEvent",function(tex,button,state,mods)
				if(button == input.MOUSE_BUTTON_RIGHT) then
					if(state == input.STATE_PRESS) then
						local boneName = memberComponents[2]
						local mdlName = actor:GetModel()
						local mdl = (mdlName ~= nil) and game.load_model(mdlName) or nil
						local boneId = (mdl ~= nil) and mdl:LookupBone(boneName) or -1
						if(boneId ~= -1) then
							local skeleton = mdl:GetSkeleton()
							local bone = skeleton:GetBone(boneId)
							local numParents = 0
							local parent = bone:GetParent()

							while(parent ~= nil) do
								numParents = numParents +1
								parent = parent:GetParent()
							end

							if(numParents > 0) then
								local pContext = gui.open_context_menu()
								if(util.is_valid(pContext) == false) then return end
								pContext:SetPos(input.get_cursor_pos())

								local ikItem,ikMenu = pContext:AddSubMenu(locale.get_text("pfm_actor_editor_add_ik_control"))
								parent = bone:GetParent()
								for i=1,numParents do
									ikMenu:AddItem(locale.get_text("pfm_actor_editor_add_ik_control_chain",{i +1,parent:GetName()}),function()
										self:AddIkController(actor,boneName,i +1)
									end)
									parent = parent:GetParent()
								end
								ikMenu:Update()

								pContext:Update()
							end
						end
					end
					return util.EVENT_REPLY_HANDLED
				end
			end)
		end
	end

	local child = baseItem:AddItem(propertyPathComponents[#propertyPathComponents],nil,nil,identifier)
	child:AddCallback("OnMouseEvent",function(tex,button,state,mods)
		if(button == input.MOUSE_BUTTON_RIGHT) then
			return util.EVENT_REPLY_HANDLED
		end
	end)

	local ctrl
	local selectedCount = 0
	local fOnSelected = function()
		selectedCount = selectedCount +1
		if(selectedCount > 1 or util.is_valid(ctrl)) then return end
		ctrl = self:OnControlSelected(actor,actorData,udmComponent,controlData)
		if(ctrl ~= nil) then
			local uid = tostring(actor:GetUniqueId())
			self.m_activeControls[uid] = self.m_activeControls[uid] or {}
			self.m_activeControls[uid][controlData.path] = {
				actor = actor,
				control = ctrl,
				controlData = controlData
			}
		end
	end
	local fOnDeselected = function()
		selectedCount = selectedCount -1
		if(selectedCount > 0) then return end
		self:CallCallbacks("OnControlDeselected",udmComponent,controlData,ctrl)
		if(actor:IsValid()) then
			local uid = tostring(actor:GetUniqueId())
			if(self.m_activeControls[uid] ~= nil) then
				self.m_activeControls[uid][controlData.path] = nil
				if(table.is_empty(self.m_activeControls[uid])) then self.m_activeControls[uid] = nil end
			end
		end
		if(util.is_valid(ctrl) == false) then return end
		ctrl:Remove()
	end
	if(controlData.type == "bone") then
		local function add_item(parent,name)
			local item = parent:AddItem(name)
			item:AddCallback("OnSelected",fOnSelected)
			item:AddCallback("OnDeselected",fOnDeselected)
			return item
		end

		local childPos = child:AddItem("pos")
		add_item(childPos,"x")
		add_item(childPos,"y")
		add_item(childPos,"z")

		local childRot = child:AddItem("rot")
		add_item(childRot,"x")
		add_item(childRot,"y")
		add_item(childRot,"z")
	else
		child:AddCallback("OnSelected",fOnSelected)
		child:AddCallback("OnDeselected",fOnDeselected)
	end
	return ctrl
end
function gui.PFMActorEditor:InitializeNavigationBar()
	--[[self.m_btHome = gui.PFMButton.create(self.navBar,"gui/pfm/icon_nav_home","gui/pfm/icon_nav_home_activated",function()
		if(self.m_rootNode == nil) then return end
		self:GetHistory():Clear()
		self:GetHistory():Add(self.m_rootNode)
	end)
	gui.create("WIBase",self.navBar):SetSize(5,1) -- Gap

	self.m_btUp = gui.PFMButton.create(self.navBar,"gui/pfm/icon_nav_up","gui/pfm/icon_nav_up_activated",function()
		print("TODO")
	end)
	self.m_btUp:SetupContextMenu(function(pContext)
		print("TODO")
	end)

	gui.create("WIBase",self.navBar):SetSize(5,1) -- Gap

	self.m_btBack = gui.PFMButton.create(self.navBar,"gui/pfm/icon_nav_back","gui/pfm/icon_nav_back_activated",function()
		self:GetHistory():GoBack()
	end)
	self.m_btBack:SetupContextMenu(function(pContext)
		local history = self:GetHistory()
		local pos = history:GetCurrentPosition()
		if(pos > 1) then
			for i=pos -1,1,-1 do
				local el = history:Get(i)
				pContext:AddItem(el:GetName(),function()
					history:SetCurrentPosition(i)
				end)
			end
		end
		pContext:AddLine()
		pContext:AddItem(locale.get_text("pfm_reset_history"),function()
			history:Clear()
		end)
	end)

	gui.create("WIBase",self.navBar):SetSize(5,1) -- Gap

	self.m_btForward = gui.PFMButton.create(self.navBar,"gui/pfm/icon_nav_forward","gui/pfm/icon_nav_forward_activated",function()
		self:GetHistory():GoForward()
	end)
	self.m_btForward:SetupContextMenu(function(pContext)
		local history = self:GetHistory()
		local pos = history:GetCurrentPosition()
		local numItems = #history
		if(pos < numItems) then
			for i=pos +1,numItems do
				local el = history:Get(i)
				pContext:AddItem(el:GetName(),function()
					history:SetCurrentPosition(i)
				end)
			end
		end
		pContext:AddLine()
		pContext:AddItem(locale.get_text("pfm_reset_history"),function()
			history:Clear()
		end)
	end)]]
end
gui.register("WIPFMActorEditor",gui.PFMActorEditor)
