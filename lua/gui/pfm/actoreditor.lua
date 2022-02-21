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
				local actor = self:CreateNewActor()
				if(actor == nil) then return end
				local mdlC = self:CreateNewActorComponent(actor,"pfm_model",nil,function(mdlC) actor:ChangeModel(mdlName) end)
				self:CreateNewActorComponent(actor,"pfm_animation_set")
				self:CreateNewActorComponent(actor,"model")
				self:CreateNewActorComponent(actor,"render")
				self:CreateNewActorComponent(actor,"animated")
				self:CreateNewActorComponent(actor,"flex")
				-- self:CreateNewActorComponent(actor,"transform")
			end)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_prop"),function()
			gui.open_model_dialog(function(dialogResult,mdlName)
				if(dialogResult ~= gui.DIALOG_RESULT_OK) then return end
				if(self:IsValid() == false) then return end
				local actor = self:CreateNewActor()
				if(actor == nil) then return end
				local mdlC = self:CreateNewActorComponent(actor,"pfm_model",nil,function(mdlC) actor:ChangeModel(mdlName) end)
				self:CreateNewActorComponent(actor,"model")
				self:CreateNewActorComponent(actor,"render")
				-- self:CreateNewActorComponent(actor,"transform")
			end)
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_camera"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_camera")
			-- self:CreateNewActorComponent(actor,"toggle")
			self:CreateNewActorComponent(actor,"camera")
			-- self:CreateNewActorComponent(actor,"transform")
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_particle_system"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_particle_system")
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_spot_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_spot")
			self:CreateNewActorComponent(actor,"light")
			self:CreateNewActorComponent(actor,"light_spot")
			self:CreateNewActorComponent(actor,"radius")
			self:CreateNewActorComponent(actor,"color")
			-- self:CreateNewActorComponent(actor,"transform")
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_point_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_point")
			self:CreateNewActorComponent(actor,"light")
			self:CreateNewActorComponent(actor,"light_point")
			self:CreateNewActorComponent(actor,"radius")
			self:CreateNewActorComponent(actor,"color")
			-- self:CreateNewActorComponent(actor,"transform")
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_directional_light"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			self:CreateNewActorComponent(actor,"pfm_light_directional")
			self:CreateNewActorComponent(actor,"light")
			self:CreateNewActorComponent(actor,"light_directional")
			self:CreateNewActorComponent(actor,"color")
			-- self:CreateNewActorComponent(actor,"transform")
		end)
		pContext:AddItem(locale.get_text("pfm_create_new_volume"),function()
			local actor = self:CreateNewActor()
			if(actor == nil) then return end
			local mdlData = self:CreateNewActorComponent(actor,"pfm_model")
			self:CreateNewActorComponent(actor,"pfm_volumetric")
			mdlData:SetModelName("cube")

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

			local transform = actor:GetTransform()
			transform:SetOrigin(center)
			transform:SetRotation(Quaternion())
			transform:SetScale(extents)
		end)

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

	local animSetControls = gui.create("WIPFMControlsMenu",dataVBox)
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
	return slider
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
function gui.PFMActorEditor:CreateNewActor()
	local filmClip = self:GetFilmClip()
	if(filmClip == nil) then
		pfm.create_popup_message(locale.get_text("pfm_popup_create_actor_no_film_clip"))
		return
	end
	local actor = pfm.get_project_manager():AddActor(self:GetFilmClip())
	local actorName = "actor"

	local actorIndex = 1
	while(filmClip:FindActor(actorName .. actorIndex) ~= nil) do actorIndex = actorIndex +1 end
	actor:SetName(actorName .. actorIndex)

	local pos = Vector()
	local rot = Quaternion()
	local cam = tool.get_filmmaker():GetActiveCamera()
	if(util.is_valid(cam)) then
		local entCam = cam:GetEntity()
		pos = entCam:GetPos() +entCam:GetForward() *100.0
		rot = EulerAngles(0,entCam:GetAngles().y,0):ToQuaternion()
	end
	local t = actor:GetTransform()
	t:SetOrigin(pos)
	t:SetRotation(rot)

	self:AddActor(actor)
	return actor
end
function gui.PFMActorEditor:CreateNewActorComponent(actor,componentType,updateActor,initComponent)
	local itemActor
	for elTree,data in pairs(self.m_treeElementToActorData) do
		if(util.is_same_object(actor,data.actor)) then
			itemActor = elTree
			break
		end
	end

	if(itemActor == nil) then return end

	include_component(componentType)
	local componentId = ents.find_component_id(componentType)
	if(componentId == nil) then pfm.log("Attempted to add unknown entity component '" .. componentType .. "' to actor '" .. tostring(actor) .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING) return end

	local component = actor:AddComponentType(componentType)
	if(initComponent ~= nil) then initComponent(component) end

	if(updateActor == true) then tool.get_filmmaker():UpdateActor(actor,self:GetFilmClip(),true) end

	local actorData = self.m_treeElementToActorData[itemActor]
	self:UpdateActorComponentEntries(actorData)

	return component
end
function gui.PFMActorEditor:TagRenderSceneAsDirty(dirty)
	tool.get_filmmaker():TagRenderSceneAsDirty(dirty)
end
local function applyComponentChannelValue(actorEditor,component,controlData,value)
	local parent = component:GetSceneParent()
	if(parent ~= nil and controlData.path ~= nil and parent:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR) then
		actorEditor:SetAnimationChannelValue(parent,controlData.path,value)
	end
end
function gui.PFMActorEditor:AddSliderControl(component,controlData)
	if(util.is_valid(self.m_animSetControls) == false) then return end

	local function applyValue(value)
		local parent = component:GetSceneParent()
		if(parent ~= nil and controlData.path ~= nil and parent:GetType() == fudm.ELEMENT_TYPE_PFM_ACTOR) then
			self:SetAnimationChannelValue(parent,controlData.path,value)
		end
	end

	local slider = self.m_animSetControls:AddSliderControl(controlData.name,controlData.identifier,controlData.translateToInterface(controlData.default or 0.0),controlData.translateToInterface(controlData.min or 0.0),controlData.translateToInterface(controlData.max or 100),nil,nil,controlData.integer or controlData.boolean)
	if(controlData.default ~= nil) then slider:SetDefault(controlData.translateToInterface(controlData.default)) end
	if(controlData.value ~= nil) then slider:SetValue(controlData.translateToInterface(controlData.value)) end
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
		if(controlData.boolean) then value = toboolean(value) end
		if(controlData.set ~= nil) then
			controlData.set(component,value)
		end
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
					debug.print("Set exprewssion: ",expr)
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
					--debug.print("Set exprewssion!")
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
function gui.PFMActorEditor:SetAnimationChannelValue(actor,path,value)
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
			local channel = channelClip:GetChannel(path,type,true)

			local time = fm:GetTimeOffset()
			pfm.log("Adding channel value " .. tostring(value) .. " of type " .. udm.type_to_string(type) .. " at timestamp " .. time .. " with channel path '" .. path .. "' to actor '" .. tostring(actor) .. "'...",pfm.LOG_CATEGORY_PFM)
			local localTime = channelClip:GetTimeFrame():LocalizeTimeOffset(time)
			local anim = channelClip:GetPanimaAnimation()
			local channelValue = value
			if(util.get_type_name(channelValue) == "Color") then channelValue = channelValue:ToVector() end
			anim:FindChannel(path):AddValue(localTime,channelValue)
			animManager:SetChannelValue(actor,path,localTime,channelValue,channelClip,type)
			animManager:SetAnimationsDirty()
			fm:TagRenderSceneAsDirty()
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
function gui.PFMActorEditor:UpdateActorComponentEntries(actorData)
	self.m_dirtyActorEntries = self.m_dirtyActorEntries or {}
	self.m_dirtyActorEntries[actorData.actor:GetUniqueId()] = true
	local entActor = actorData.actor:FindEntity()
	if(entActor ~= nil) then self:InitializeDirtyActorComponents(actorData.actor:GetUniqueId(),entActor) end
end
function gui.PFMActorEditor:InitializeDirtyActorComponents(uniqueId,entActor)
	if(type(uniqueId) ~= "string") then uniqueId = tostring(uniqueId) end
	if(self.m_dirtyActorEntries == nil or self.m_dirtyActorEntries[uniqueId] == nil) then return end
	entActor = entActor or ents.find_by_unique_index(uniqueId)
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
	local componentId = ents.find_component_id(component:GetType())
	if(componentId == nil) then return end
	actorData.componentData[componentId] = actorData.componentData[componentId] or {
		items = {}
	}
	local componentData = actorData.componentData[componentId]
	local itemComponent = actorData.componentsEntry:AddItem(component:GetName(),nil,nil,component:GetType())
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
		local props = component:GetProperty("properties")
		local function initializeProperty(info,controlData)
			local prop = props:GetProperty(info.name)
			if(prop ~= nil) then
				c:SetMemberValue(info.name,prop:GetValue())
				return true
			end
			local valid = true
			if(info.type == udm.TYPE_STRING) then props:SetProperty(info.name,fudm.String(info.default))
			elseif(info.type == udm.TYPE_UINT8) then
				props:SetProperty(info.name,fudm.UInt8(info.default))
				controlData.integer = true
			elseif(info.type == udm.TYPE_INT32) then
				props:SetProperty(info.name,fudm.Int(info.default))
				controlData.integer = true
			elseif(info.type == udm.TYPE_UINT32) then
				props:SetProperty(info.name,fudm.UInt32(info.default))
				controlData.integer = true
			elseif(info.type == udm.TYPE_UINT64) then
				props:SetProperty(info.name,fudm.UInt64(info.default))
				controlData.integer = true
			elseif(info.type == udm.TYPE_FLOAT) then props:SetProperty(info.name,fudm.Float(info.default))
			elseif(info.type == udm.TYPE_BOOLEAN) then
				props:SetProperty(info.name,fudm.Bool(info.default))
				controlData.boolean = true
			elseif(info.type == udm.TYPE_VECTOR2) then
				props:SetProperty(info.name,fudm.Vector2(info.default))
				valid = false
			elseif(info.type == udm.TYPE_VECTOR3) then
				props:SetProperty(info.name,fudm.Vector3(info.default))
				if(info.specializationType ~= ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_COLOR) then
					-- valid = false
				end
			elseif(info.type == udm.TYPE_VECTOR4) then
				props:SetProperty(info.name,fudm.Vector4(info.default))
				valid = false
			elseif(info.type == udm.TYPE_QUATERNION) then
				props:SetProperty(info.name,fudm.Quaternion(info.default))
				-- valid = false
			elseif(info.type == udm.TYPE_EULER_ANGLES) then
				props:SetProperty(info.name,fudm.Angle(info.default))
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

		local memberIdx = 0
		local memberInfo = (c ~= nil) and c:GetMemberInfo(memberIdx) or nil
		while(memberInfo ~= nil) do
			local controlData = {}
			local info = memberInfo
			local path = "ec/" .. componentInfo.name .. "/" .. info.name
			local valid = initializeProperty(info,controlData)
			if(valid) then
				controlData.name = info.name
				controlData.default = info.default
				controlData.path = path
				controlData.value = c:GetMemberValue(info.name)
				if(udm.is_numeric_type(info.type)) then
					local min = info.min or 0
					local max = info.max or 100
					min = math.min(min,controlData.default or min,controlData.value or min)
					max = math.max(max,controlData.default or max,controlData.value or max)
					if(min == max) then max = max +100 end
					controlData.min = min
					controlData.max = max
				end
				pfm.log("Adding control for member '" .. controlData.path .. "' with min = " .. (tostring(controlData.min) or "nil") .. ", max = " .. (tostring(controlData.max) or "nil") .. ", default = " .. (tostring(controlData.default) or "nil") .. ", value = " .. (tostring(controlData.value) or "nil") .. "...",pfm.LOG_CATEGORY_PFM)
				controlData.set = function(component,value,dontTranslateValue)
					local entActor = ents.find_by_unique_index(uniqueId)
					local c = (entActor ~= nil) and entActor:GetComponent(componentId) or nil
					local memberIdx = (c ~= nil) and c:GetMemberIndex(controlData.name) or nil
					local info = (memberIdx ~= nil) and c:GetMemberInfo(memberIdx) or nil
					if(info == nil) then return end
					if(dontTranslateValue ~= true) then value = controlData.translateFromInterface(value) end
					local memberValue = value
					if(util.get_type_name(memberValue) == "Color") then memberValue = memberValue:ToVector() end

					if(controlData.name == "angles") then
						actorData.actor:GetProperty("transform"):GetProperty("rotation"):SetValue(memberValue:ToQuaternion())
					else
						component:GetProperty("properties"):GetProperty(info.name):SetValue(memberValue)
					end
					
					local entActor = actorData.actor:FindEntity()
					if(entActor ~= nil) then
						local c = entActor:GetComponent(componentId)
						if(c ~= nil) then
							c:SetMemberValue(info.name,memberValue)
							self:OnActorPropertyChanged(entActor)
						end
					end
					applyComponentChannelValue(self,component,controlData,memberValue)
					self:TagRenderSceneAsDirty()
				end
				controlData.set(component,controlData.value,true)
				actorData.componentData[componentId].items[memberIdx] = self:AddControl(entActor,c,actorData,componentData,component,itemComponent,controlData,path)
			else
				pfm.log("Unable to add control for member '" .. path .. "'!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
			end
			memberIdx = memberIdx +1
			memberInfo = c:GetMemberInfo(memberIdx)
		end
	end
	--[[if(component.SetupControls) then
		-- component:SetupControls(self,itemComponent)
	end]]

	-- TODO: Use the code below once the system has been fully transitioned to UDM
	--[[local itemComponent = itemComponents:AddItem(component:GetName())
	if(component.GetIconMaterial) then
		itemComponent:AddIcon(component:GetIconMaterial())
		itemActor:AddIcon(component:GetIconMaterial())
	end
	local function stringToFunction(str)
		if(str == nil) then return end
		local f = loadstring("return " .. str)
		if(f == nil or type(f) ~= "function") then return end
		return f()
	end
	local function getText(udm,key,localizedKey)
		local text = udm:GetValue(localizedKey)
		if(text ~= nil) then text = locale.get_text(text)
		else text = udm:GetValue(key) end
		return text or ""
	end
	local udmComponent = self.m_componentManager:GetComponents():Get(component:GetComponentName())
	if(udmComponent:IsValid()) then

		for _,udmControl in ipairs(udmComponent:GetArrayValues("controls")) do
			local type = udmControl:GetValue("type")
			local name = getText(udmControl,"label","localizedLabel")

			local udmLua = udmControl:Get("lua")
			local identifier = udmControl:GetValue("identifier")

			if(type == "slider") then
				local ctrlSettings = {
					name = name,
					property = udmControl:GetValue("keyValue"),
					min = udmControl:GetValue("min"),
					max = udmControl:GetValue("max"),
					default = udmControl:GetValue("default")
				}

				ctrlSettings.translateToInterface = stringToFunction(udmLua:GetValue("translateToInterface"))
				ctrlSettings.translateFromInterface = stringToFunction(udmLua:GetValue("translateFromInterface"))

				local unit = getText(udmControl,"unit","localizedUnit")
				if(#unit > 0) then ctrlSettings["unit"] = unit end
				self:AddControl(component,itemComponent,ctrlSettings)
			elseif(type == "color") then
				local ctrlSettings = {
					name = name,
					addControl = function(ctrls)
						local colField,wrapper = ctrls:AddColorField(locale.get_text("color"),"color",self:GetColor(),function(oldCol,newCol)
							self:SetColor(newCol)
							self:TagRenderSceneAsDirty()
						end)
						return wrapper
					end
				}
				self:AddControl(component,itemComponent,ctrlSettings)
			elseif(type == "drop_down_menu") then
				local options = {}
				for _,udmOption in ipairs(udmControl:GetArrayValues("options")) do
					local value = udmOption:GetValue("value")
					local name = locale.get_text(udmOption:GetValue("localizedDisplayText"))
					table.insert(options,{value,name})
				end
				local onChange = stringToFunction(udmLua:GetValue("onChange"))
				local ctrlSettings = {
					name = name,
					addControl = function(ctrls)
						local fOnChange = onChange
						if(fOnChange ~= nil) then
							fOnChange = function(menu,option) onChange(ctrls,menu,option) end
						end
						local menu,wrapper = ctrls:AddDropDownMenu(name,identifier,options,udmControl:GetValue("default") or 0,fOnChange)
						return wrapper
					end
				}
				self:AddControl(component,itemComponent,ctrlSettings)
			end
		end
	end]]
end
function gui.PFMActorEditor:AddActor(actor)
	local itemActor = self.m_tree:AddItem(actor:GetName())

	itemActor:AddCallback("OnMouseEvent",function(tex,button,state,mods)
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
	self.m_actorUniqueIdToTreeElement[actor:GetUniqueId()] = itemActor
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
			--[[local componentManager = self.m_componentManager
			local components = {}
			for componentType,udmComponent in pairs(componentManager:GetComponents():GetChildren()) do
				local name = udmComponent:GetValue("name")
				if(name == nil) then
					local valid,n = locale.get_text("component_" .. componentType,nil,true)
					if(valid) then name = n
					else name = componentType end
				end
				locale.get_text("pfm_add_component_type",{name})
				pComponentsMenu:AddItem(locale.get_text("pfm_add_component_type",{componentType}),function()
					local tTranslation = {
						["pfm_model"] = {"PFMModel"},
						["pfm_particle_system"] = {"PFMParticleSystem"},
						["pfm_camera"] = {"PFMCamera"},
						["pfm_animation_set"] = {"PFMAnimationSet"},
						["pfm_light_spot"] = {"PFMSpotLight","light","light_spot","radius","color","transform"},
						["pfm_light_directional"] = {"PFMDirectionalLight"},
						["pfm_light_point"] = {"PFMPointLight"},
						["pfm_impersonatee"] = {"PFMImpersonatee"},
						["pfm_volumetric"] = {"PFMVolumetric"}
					}
					for _,componentName in pairs(tTranslation[componentType]) do
						self:CreateNewActorComponent(actor,componentName,true)
					end
				end)
			end]]
			pContext:Update()
			return util.EVENT_REPLY_HANDLED
		end
	end)
	self:UpdateActorComponentEntries(self.m_treeElementToActorData[itemActor])
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
function gui.PFMActorEditor:AddControl(entActor,component,actorData,componentData,udmComponent,item,controlData,identifier)
	local actor = udmComponent:GetSceneParent()
	local memberInfo = (actor ~= nil) and self:GetMemberInfo(actor,controlData.path) or nil
	if(memberInfo == nil) then return end
	controlData.translateToInterface = controlData.translateToInterface or function(val) return val end
	controlData.translateFromInterface = controlData.translateFromInterface or function(val) return val end

	local isBaseProperty = (memberInfo.type == udm.TYPE_STRING)
	local baseItem = isBaseProperty and componentData.itemBaseProps or item
	local child = baseItem:AddItem(controlData.name,nil,nil,identifier)

	local ctrl
	local selectedCount = 0
	local fOnSelected = function()
		selectedCount = selectedCount +1
		if(selectedCount > 1 or util.is_valid(ctrl)) then return end
		if(controlData.path ~= nil) then
			if(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_COLOR) then
				local colField,wrapper = self.m_animSetControls:AddColorField(memberInfo.name,"color",(controlData.value and Color(controlData.value)) or (controlData.default and Color(controlData.default)) or Color.White,function(oldCol,newCol)
					if(controlData.set ~= nil) then controlData.set(udmComponent,newCol) end
				end)
				ctrl = wrapper
			elseif(memberInfo.type == udm.TYPE_STRING) then
				if(memberInfo.specializationType == ents.ComponentInfo.MemberInfo.SPECIALIZATION_TYPE_FILE) then
					local meta = memberInfo.metaData or udm.create_element()
					if(meta ~= nil) then
						if(meta:GetValue("assetType") == "model") then
							ctrl = self:AddProperty(memberInfo.name,child,function(parent)
								local el = gui.create("WIFileEntry",parent)
								if(controlData.value ~= nil) then el:SetValue(controlData.value) end
								el:SetBrowseHandler(function(resultHandler)
									gui.open_model_dialog(function(dialogResult,mdlName)
										if(dialogResult ~= gui.DIALOG_RESULT_OK) then return end
										resultHandler(mdlName)
									end)
								end)
								el:AddCallback("OnValueChanged",function(el,value)
									if(controlData.set ~= nil) then controlData.set(udmComponent,value) end
								end)
								return el
							end)
						end
					end
					if(util.is_valid(ctrl) == false) then
						ctrl = self:AddProperty(memberInfo.name,child,function(parent)
							local el = gui.create("WIFileEntry",parent)
							if(controlData.value ~= nil) then el:SetValue(controlData.value) end
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
								if(controlData.set ~= nil) then controlData.set(udmComponent,value) end
							end)
							return el
						end)
					end
				end
				return
			elseif(udm.is_numeric_type(memberInfo.type)) then
				if(memberInfo.minValue ~= nil) then controlData.min = memberInfo.minValue end
				if(memberInfo.maxValue ~= nil) then controlData.max = memberInfo.maxValue end
				if(memberInfo.default ~= nil) then controlData.default = memberInfo.default end
				if(memberInfo.value ~= nil) then controlData.value = memberInfo.value end

				if(memberInfo.type == udm.TYPE_BOOLEAN) then
					controlData.min = controlData.min and 1 or 0
					controlData.max = controlData.max and 1 or 0
					controlData.default = controlData.default and 1 or 0
					controlData.value = controlData.value and 1 or 0
				end

				local channel = self:GetAnimationChannel(actorData.actor,controlData.path,false)
				local hasExpression = (channel ~= nil and #channel:GetExpression() > 0)
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
				ctrl:AddCallback("PopulateContextMenu",function(ctrl,context)
					local pm = pfm.get_project_manager()
					local animManager = pm:GetAnimationManager()
					if(animManager ~= nil) then
						local expr = animManager:GetValueExpression(actorData.actor,controlData.path)
						if(expr ~= nil) then
							context:AddItem(locale.get_text("pfm_clear_expression"),function()
								animManager:SetValueExpression(actorData.actor,controlData.path)
							end)
							context:AddItem(locale.get_text("pfm_copy_expression"),function() util.set_clipboard_string(expr) end)
						end
						context:AddItem(locale.get_text("pfm_set_expression"),function()
							local te
							local p = pfm.open_entry_edit_window(locale.get_text("pfm_set_expression"),function(ok)
								if(ok) then
									animManager:SetValueExpression(actorData.actor,controlData.path,te:GetText())
								end
							end)
							te = p:AddTextField(locale.get_text("pfm_expression") .. ":",expr or "")
							te:GetTextElement():SetFont("pfm_medium")

							p:SetWindowSize(Vector2i(800,120))
							p:Update()
						end)
						local anim,channel = animManager:FindAnimationChannel(actorData.actor,controlData.path,false)
						if(channel ~= nil) then
							context:AddItem(locale.get_text("pfm_clear_animation"),function()
								animManager:RemoveChannel(actorData.actor,controlData.path)
								local entActor = actorData.actor:FindEntity()
								local actorC = util.is_valid(entActor) and entActor:GetComponent(ents.COMPONENT_PFM_ACTOR) or nil
								if(actorC ~= nil) then
									actorC:ApplyComponentMemberValue(controlData.path)
								end
							end)
						end
					end
				end)
				if(controlData.unit) then ctrl:SetUnit(controlData.unit) end

				-- pfm.log("Attempted to add control for member with path '" .. controlData.path .. "' of actor '" .. tostring(actor) .. "', but member type " .. tostring(memberInfo.specializationType) .. " is unknown!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
			elseif(memberInfo.type == udm.TYPE_EULER_ANGLES) then
				local el,wrapper = self.m_animSetControls:AddTextEntry(memberInfo.name,memberInfo.name,tostring(memberInfo.value),function(el)
					if(controlData.set ~= nil) then controlData.set(udmComponent,EulerAngles(el:GetText())) end
				end)
				ctrl = wrapper
			else return end
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
		self:CallCallbacks("OnControlSelected",udmComponent,controlData,ctrl)
	end
	local fOnDeselected = function()
		selectedCount = selectedCount -1
		if(selectedCount > 0) then return end
		self:CallCallbacks("OnControlDeselected",udmComponent,controlData,ctrl)
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
