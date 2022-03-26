--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/gui/curve.lua")
include("/gui/pfm/treeview.lua")
include("/gui/pfm/grid.lua")
include("/gui/pfm/selection.lua")
include("/gui/selectionrect.lua")
include("/gui/timelinestrip.lua")
include("/graph_axis.lua")
include("key.lua")
include("easing.lua")

util.register_class("gui.CursorTracker",util.CallbackHandler)
function gui.CursorTracker:__init()
	util.CallbackHandler.__init(self)
	self.m_startPos = input.get_cursor_pos()
	self.m_curPos = self.m_startPos:Copy()
end

function gui.CursorTracker:GetTotalDeltaPosition() return self.m_curPos -self.m_startPos end

function gui.CursorTracker:Update()
	local pos = input.get_cursor_pos()
	local dt = pos -self.m_curPos
	if(dt.x == 0 and dt.y == 0) then return dt end
	self.m_curPos = pos
	self:CallCallbacks("OnCursorMoved",dt)
	return dt
end

----------------

util.register_class("gui.PFMDataPointControl",gui.Base)
function gui.PFMDataPointControl:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(4,4)
	local el = gui.create("WIRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_elPoint = el
	el:GetColorProperty():Link(self:GetColorProperty())

	self.m_selected = false
	self:SetMouseInputEnabled(true)
end
function gui.PFMDataPointControl:IsSelected() return self.m_selected end
function gui.PFMDataPointControl:SetSelected(selected)
	if(selected == self.m_selected) then return end
	self.m_selected = selected
	self:SetColor(selected and Color.Red or Color.White)
	self:OnSelectionChanged(selected)
	self:CallCallbacks("OnSelectionChanged",selected)
end
function gui.PFMDataPointControl:OnSelectionChanged(selected) end
function gui.PFMDataPointControl:OnThink()
	if(self.m_cursorTracker == nil) then return end
	local dt = self.m_cursorTracker:Update()
	if(dt.x == 0 and dt.y == 0) then return end
	local newPos = self.m_moveModeStartPos +self.m_cursorTracker:GetTotalDeltaPosition()
	self:OnMoved(newPos)
	self:CallCallbacks("OnMoved",newPos)
end
function gui.PFMDataPointControl:OnMoved(newPos) end
function gui.PFMDataPointControl:IsMoveModeEnabled() return self.m_cursorTracker ~= nil end
function gui.PFMDataPointControl:SetMoveModeEnabled(enabled)
	if(enabled) then
		self.m_cursorTracker = gui.CursorTracker()
		self.m_moveModeStartPos = self:GetPos()
		self:EnableThinking()
	else
		self.m_cursorTracker = nil
		self.m_moveModeStartPos = nil
		self:DisableThinking()
	end
end
gui.register("WIPFMDataPointControl",gui.PFMDataPointControl)

----------------

util.register_class("gui.PFMTimelineTangentControl",gui.Base)
function gui.PFMTimelineTangentControl:OnInitialize()
	gui.Base.OnInitialize(self)

	local lineIn = gui.create("WILine",self:GetParent())
	lineIn:SetColor(Color.Red)
	self.m_inLine = lineIn

	local ctrlIn = gui.create("WIPFMDataPointControl",self:GetParent())
	ctrlIn:SetColor(Color.Black)
	self.m_inCtrl = ctrlIn

	local lineOut = gui.create("WILine",self:GetParent())
	lineOut:SetColor(Color.Aqua)
	self.m_outLine = lineOut

	local ctrlOut = gui.create("WIPFMDataPointControl",self:GetParent())
	ctrlOut:SetColor(Color.Black)
	self.m_outCtrl = ctrlOut

	self.m_inCtrl:AddCallback("OnMoved",function(ctrl,newPos) self:UpdateInControl(newPos) end)
	self.m_outCtrl:AddCallback("OnMoved",function(ctrl,newPos) self:UpdateOutControl(newPos) end)

	self.m_inLine:GetVisibilityProperty():Link(self:GetVisibilityProperty())
	self.m_inCtrl:GetVisibilityProperty():Link(self:GetVisibilityProperty())
	self.m_outLine:GetVisibilityProperty():Link(self:GetVisibilityProperty())
	self.m_outCtrl:GetVisibilityProperty():Link(self:GetVisibilityProperty())
end
function gui.PFMTimelineTangentControl:GetInControl() return self.m_inCtrl end
function gui.PFMTimelineTangentControl:GetOutControl() return self.m_outCtrl end
function gui.PFMTimelineTangentControl:UpdateInControl(newPos)
	self:CallCallbacks("OnInControlMoved",newPos)
end
function gui.PFMTimelineTangentControl:UpdateOutControl(newPos)
	self:CallCallbacks("OnOutControlMoved",newPos)
end
function gui.PFMTimelineTangentControl:OnUpdate()
	self:UpdateInOutLines(true,true)
end
function gui.PFMTimelineTangentControl:SetDataPoint(dp) self.m_dataPoint = dp end
function gui.PFMTimelineTangentControl:UpdateInOutLines(updateIn,updateOut)
	if(util.is_valid(self.m_dataPoint) == false) then return end
	local pos = self:GetCenter()

	local curve = self.m_dataPoint:GetGraphCurve()

	local editorChannel = curve:GetEditorChannel()
	if(editorChannel == nil) then return end

	local editorGraphCurve = editorChannel:GetGraphCurve()
	local editorKeys = editorGraphCurve:GetKey(self.m_dataPoint:GetTypeComponentIndex())

	local keyIndex = self.m_dataPoint:GetKeyIndex()

	local graph = curve:GetTimelineGraph()
	local timeAxis = graph:GetTimeAxis()
	local dataAxis = graph:GetDataAxis()

	local basePos = self.m_dataPoint:GetCenter()
	if(updateIn) then
		local inTime = editorKeys:GetInTime(keyIndex)
		local inDelta = editorKeys:GetInDelta(keyIndex)

		inTime = timeAxis:GetAxis():ValueToXDelta(inTime)
		inDelta = -dataAxis:GetAxis():ValueToXDelta(inDelta)

		local inPos = basePos +Vector2(inTime,inDelta)
		self.m_inCtrl:SetPos(inPos)

		self.m_inLine:SetStartPos(inPos)
		self.m_inLine:SetEndPos(Vector2(pos.x,pos.y))
		self.m_inLine:SizeToContents()
	end

	if(updateOut) then
		local outTime = editorKeys:GetOutTime(keyIndex)
		local outDelta = editorKeys:GetOutDelta(keyIndex)
		
		outTime = timeAxis:GetAxis():ValueToXDelta(outTime)
		outDelta = -dataAxis:GetAxis():ValueToXDelta(outDelta)

		local outPos = basePos +Vector2(outTime,outDelta)
		self.m_outCtrl:SetPos(outPos)

		self.m_outLine:SetStartPos(outPos)
		self.m_outLine:SetEndPos(Vector2(pos.x,pos.y))
		self.m_outLine:SizeToContents()
	end
end
function gui.PFMTimelineTangentControl:OnRemove()
	util.remove({self.m_inLine,self.m_outLine,self.m_inCtrl,self.m_outCtrl})
end
gui.register("WIPFMTimelineTangentControl",gui.PFMTimelineTangentControl)

----------------

util.register_class("gui.PFMTimelineDataPoint",gui.PFMDataPointControl)
function gui.PFMTimelineDataPoint:OnInitialize()
	gui.PFMDataPointControl.OnInitialize(self)
end
function gui.PFMTimelineDataPoint:OnSelectionChanged(selected)
	self:UpdateTextFields()
end
function gui.PFMTimelineDataPoint:GetTangentControl() return self.m_tangentControl end
function gui.PFMTimelineDataPoint:GetEditorKeys()
	local curve = self:GetGraphCurve()
	local graph = curve:GetTimelineGraph()

	local editorChannel = curve:GetEditorChannel()
	if(editorChannel == nil) then return end

	local editorGraphCurve = editorChannel:GetGraphCurve()
	local editorKeys = editorGraphCurve:GetKey(self:GetTypeComponentIndex())
	return editorKeys,self:GetKeyIndex()
end
function gui.PFMTimelineDataPoint:ReloadGraphCurveSegment()
	local curve = self:GetGraphCurve()
	local timelineGraph = curve:GetTimelineGraph()
	timelineGraph:ReloadGraphCurveSegment(curve:GetCurveIndex(),self:GetKeyIndex())
end
function gui.PFMTimelineDataPoint:IsHandleSelected()
	if(util.is_valid(self.m_tangentControl) == false) then return false end
	return self.m_tangentControl:GetInControl():IsSelected() or self.m_tangentControl:GetOutControl():IsSelected()
end
function gui.PFMTimelineDataPoint:OnUpdate()
	if(util.is_valid(self.m_tangentControl) == false) then return end
	self.m_tangentControl:SetPos(self:GetCenter())
	self.m_tangentControl:Update()
end
function gui.PFMTimelineDataPoint:InitializeHandleControl()
	if(util.is_valid(self.m_tangentControl)) then return end
	local el = gui.create("WIPFMTimelineTangentControl",self:GetParent())
	el:SetDataPoint(self)

	local function get_key_time_delta(newPos)
		local curve = self:GetGraphCurve()
		local graph = curve:GetTimelineGraph()
		local timeAxis = graph:GetTimeAxis()
		local dataAxis = graph:GetDataAxis()

		local editorChannel = curve:GetEditorChannel()
		if(editorChannel == nil) then return end

		local editorGraphCurve = editorChannel:GetGraphCurve()
		local editorKeys = editorGraphCurve:GetKey(self:GetTypeComponentIndex())

		local keyIndex = self:GetKeyIndex()
		local val = newPos -self:GetCenter()
		local time = timeAxis:GetAxis():XDeltaToValue(val.x)
		local delta = -dataAxis:GetAxis():XDeltaToValue(val.y)
		return editorKeys,keyIndex,time,delta
	end

	el:AddCallback("OnInControlMoved",function(el,newPos)
		local editorKeys,keyIndex,time,delta = get_key_time_delta(newPos)
		time = math.min(time,-0.0001)
		editorKeys:SetInTime(keyIndex,time)
		editorKeys:SetInDelta(keyIndex,delta)
		if(util.is_valid(self.m_tangentControl)) then self.m_tangentControl:UpdateInOutLines(true,false) end
		self:ReloadGraphCurveSegment()
	end)
	el:AddCallback("OnOutControlMoved",function(el,newPos)
		local editorKeys,keyIndex,time,delta = get_key_time_delta(newPos)
		time = math.max(time,0.0001)
		editorKeys:SetOutTime(keyIndex,time)
		editorKeys:SetOutDelta(keyIndex,delta)
		if(util.is_valid(self.m_tangentControl)) then self.m_tangentControl:UpdateInOutLines(false,true) end
		self:ReloadGraphCurveSegment()
	end)

	self.m_tangentControl = el

	self:Update()
end
function gui.PFMTimelineDataPoint:OnRemove()
	util.remove(self.m_tangentControl)
end
function gui.PFMTimelineDataPoint:SetGraphData(timelineCurve,keyIndex)
	self.m_graphData = {
		timelineCurve = timelineCurve,
		keyIndex = keyIndex
	}
end
function gui.PFMTimelineDataPoint:GetKeyIndex() return self.m_graphData.keyIndex end
function gui.PFMTimelineDataPoint:SetKeyIndex(index) self.m_graphData.keyIndex = index end
function gui.PFMTimelineDataPoint:GetTime()
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve
	local actor,targetPath,keyIndex,curveData = self:GetChannelValueData()
	local editorKeys = timelineCurve:GetEditorKeys()
	return editorKeys:GetTime(keyIndex)
end
function gui.PFMTimelineDataPoint:GetValue()
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve
	local actor,targetPath,keyIndex,curveData = self:GetChannelValueData()
	local editorKeys = timelineCurve:GetEditorKeys()
	return editorKeys:GetValue(keyIndex)
end
function gui.PFMTimelineDataPoint:ChangeDataValue(t,v)
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve

	local pm = pfm.get_project_manager()
	local actor,targetPath,keyIndex,curveData = self:GetChannelValueData()
	if(v ~= nil and curveData.valueTranslator ~= nil) then
		local curTime,curVal = animManager:GetChannelValueByIndex(actor,targetPath,valueIndex)
		v = curveData.valueTranslator[2](v,curVal)
	end

	local panimaChannel = timelineCurve:GetPanimaChannel()
	t = t or self:GetTime()
	v = v or self:GetValue()
	pm:UpdateKeyframe(actor,targetPath,panimaChannel,keyIndex,t,v,self:GetTypeComponentIndex())
end
function gui.PFMTimelineDataPoint:UpdateTextFields()
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve
	local pm = pfm.get_project_manager()
	local curValue = timelineCurve:GetCurve():CoordinatesToValues(self:GetX() +self:GetWidth() /2.0,self:GetY() +self:GetHeight() /2.0)
	curValue = {curValue.x,curValue.y}
	curValue[2] = math.round(curValue[2] *100.0) /100.0 -- TODO: Make round precision dependent on animation property
	timelineCurve:GetTimelineGraph():GetTimeline():SetDataValue(
		util.round_string(pm:TimeOffsetToFrameOffset(curValue[1]),2),
		util.round_string(curValue[2],2)
	)
end
function gui.PFMTimelineDataPoint:GetGraphCurve() return self.m_graphData.timelineCurve end
function gui.PFMTimelineDataPoint:OnMoved(newPos)
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve
	local pm = pfm.get_project_manager()
	local animManager = pm:GetAnimationManager()

	local actor,targetPath,keyIndex,curveData = self:GetChannelValueData()
	-- TODO: Merge this with PFMTimelineDataPoint:UpdateTextFields()
	local newValue = timelineCurve:GetCurve():CoordinatesToValues(newPos.x +self:GetWidth() /2.0,newPos.y +self:GetHeight() /2.0)
	newValue = {newValue.x,newValue.y}
	newValue[1] = math.snap_to_gridf(newValue[1],1.0 /pm:GetFrameRate()) -- TODO: Only if snap-to-grid is enabled
	newValue[2] = math.round(newValue[2] *100.0) /100.0 -- TODO: Make round precision dependent on animation property

	if(curveData.valueTranslator ~= nil) then
		local curTime,curVal = animManager:GetChannelValueByIndex(actor,targetPath,valueIndex)
		newValue[2] = curveData.valueTranslator[2](newValue[2],curVal)
	end

	local panimaChannel = timelineCurve:GetPanimaChannel()
	pm:UpdateKeyframe(actor,targetPath,panimaChannel,keyIndex,newValue[1],newValue[2],self:GetTypeComponentIndex())
end
function gui.PFMTimelineDataPoint:GetChannelValueData()
	local graphData = self.m_graphData
	local timelineCurve = graphData.timelineCurve
	local timelineGraph = timelineCurve:GetTimelineGraph()
	local curveData = timelineGraph:GetGraphCurve(timelineCurve:GetCurveIndex())
	local animClip = curveData.animClip()
	local actor = animClip:GetActor()
	local targetPath = curveData.targetPath
	return actor,targetPath,graphData.keyIndex,curveData
end
function gui.PFMTimelineDataPoint:SetSelected(selected,keepTangentControlSelection)
	keepTangentControlSelection = keepTangentControlSelection or false
	if(selected == false and keepTangentControlSelection == false) then util.remove(self.m_tangentControl) end
	gui.PFMDataPointControl.SetSelected(self,selected)
end
function gui.PFMTimelineDataPoint:GetTypeComponentIndex() return self.m_graphData.timelineCurve:GetTypeComponentIndex() end
function gui.PFMTimelineDataPoint:UpdateSelection(elSelectionRect)
	if(elSelectionRect:IsElementInBounds(self)) then
		if(util.is_valid(self.m_tangentControl)) then
			self.m_tangentControl:GetInControl():SetSelected(false)
			self.m_tangentControl:GetOutControl():SetSelected(false)
		end
		self:SetSelected(not input.is_alt_key_down(),true)
		if(self:IsSelected()) then self:InitializeHandleControl() end
		return true
	end
	if(util.is_valid(self.m_tangentControl) == false) then return false end
	local inCtrl = self.m_tangentControl:GetInControl()
	local hasSelection = false
	if(elSelectionRect:IsElementInBounds(inCtrl)) then
		self:SetSelected(false,true)
		inCtrl:SetSelected(not input.is_alt_key_down())
		hasSelection = true
	end

	local outCtrl = self.m_tangentControl:GetOutControl()
	if(elSelectionRect:IsElementInBounds(outCtrl)) then
		self:SetSelected(false,true)
		outCtrl:SetSelected(not input.is_alt_key_down())
		hasSelection = true
	end
	return hasSelection
end
gui.register("WIPFMTimelineDataPoint",gui.PFMTimelineDataPoint)

----------------

util.register_class("gui.PFMTimelineCurve",gui.Base)
function gui.PFMTimelineCurve:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(64,64)
	local curve = gui.create("WICurve",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_curve = curve

	self.m_dataPoints = {}

	curve:GetColorProperty():Link(self:GetColorProperty())
end
function gui.PFMTimelineCurve:GetTimelineGraph() return self.m_timelineGraph end
function gui.PFMTimelineCurve:SetTimelineGraph(graph) self.m_timelineGraph = graph end
function gui.PFMTimelineCurve:GetTypeComponentIndex() return self.m_typeComponentIndex end
function gui.PFMTimelineCurve:GetCurveIndex() return self.m_curveIndex end
function gui.PFMTimelineCurve:GetCurve() return self.m_curve end
function gui.PFMTimelineCurve:GetChannel() return self.m_channel end
function gui.PFMTimelineCurve:GetPanimaChannel() return self.m_panimaChannel end
function gui.PFMTimelineCurve:GetEditorChannel() return self.m_editorChannel end
function gui.PFMTimelineCurve:GetEditorKeys()
	local editorChannel = self:GetEditorChannel()
	if(editorChannel == nil) then return end

	local editorGraphCurve = editorChannel:GetGraphCurve()
	return editorGraphCurve:GetKey(self:GetTypeComponentIndex())
end
function gui.PFMTimelineCurve:UpdateCurveData(curveValues)
	self.m_curve:BuildCurve(curveValues)
end
function gui.PFMTimelineCurve:BuildCurve(curveValues,channel,curveIndex,editorChannel,typeComponentIndex)
	self.m_channel = channel
	self.m_panimaChannel = panima.Channel(channel:GetUdmData():Get("times"),channel:GetUdmData():Get("values"))
	self.m_editorChannel = editorChannel
	self.m_curveIndex = curveIndex
	self.m_typeComponentIndex = typeComponentIndex
	self:UpdateCurveData(curveValues)

	util.remove(self.m_dataPoints)
	self.m_dataPoints = {}

	local editorGraphCurve = editorChannel:GetGraphCurve()
	local editorKeys = editorGraphCurve:GetKey(typeComponentIndex)
	local numKeys = editorKeys:GetValueCount()
	for i=0,numKeys -1 do
		local t = editorKeys:GetTime(i)

		local el = gui.create("WIPFMTimelineDataPoint",self)
		el:SetGraphData(self,i)
		el:AddCallback("OnMouseEvent",function(wrapper,button,state,mods)
			if(self.m_timelineGraph:GetCursorMode() ~= gui.PFMTimelineGraph.CURSOR_MODE_SELECT) then return util.EVENT_REPLY_UNHANDLED end
			if(button == input.MOUSE_BUTTON_LEFT) then
				if(state == input.STATE_PRESS) then
					if(util.is_valid(self.m_selectedDataPoint)) then self.m_selectedDataPoint:SetSelected(false) end
					el:SetSelected(true)
					self.m_selectedDataPoint = el
				end
				return util.EVENT_REPLY_HANDLED
			end
			wrapper:StartEditMode(false)
		end)
		--[[el:AddCallback("OnSelectionChanged",function(el,selected)

		end)]]
		self.m_selectedDataPoint = el

		table.insert(self.m_dataPoints,el)
	end
	self:UpdateDataPoints()
end
function gui.PFMTimelineCurve:UpdateDataPoint(i)
	local el = self.m_dataPoints[i]
	if(el:IsValid() == false) then return end
	local keyIndex = el:GetKeyIndex()
	local editorGraphCurve = self.m_editorChannel:GetGraphCurve()
	local editorKeys = editorGraphCurve:GetKey(self:GetTypeComponentIndex())

	local t = editorKeys:GetTime(keyIndex)
	local v = editorKeys:GetValue(keyIndex)
	local valueTranslator = self:GetTimelineGraph():GetGraphCurve(self:GetCurveIndex()).valueTranslator
	if(valueTranslator ~= nil) then v = valueTranslator[1](v) end
	local pos = self.m_curve:ValueToUiCoordinates(t,v)
	el:SetPos(pos -el:GetSize() /2.0)
	el:Update()

	if(el:IsSelected()) then el:UpdateTextFields() end
end
function gui.PFMTimelineCurve:UpdateDataPoints()
	if(self.m_editorChannel == nil) then return end
	for i=1,#self.m_dataPoints do
		self:UpdateDataPoint(i)
	end
end
function gui.PFMTimelineCurve:SwapDataPoints(idx0,idx1)
	local dp0 = self.m_dataPoints[idx0 +1]
	local dp1 = self.m_dataPoints[idx1 +1]
	dp0:SetKeyIndex(idx1)
	dp1:SetKeyIndex(idx0)
	self.m_dataPoints[idx0 +1] = dp1
	self.m_dataPoints[idx1 +1] = dp0
end
function gui.PFMTimelineCurve:GetDataPoint(idx) return self.m_dataPoints[idx +1] end
function gui.PFMTimelineCurve:GetDataPoints() return self.m_dataPoints end
function gui.PFMTimelineCurve:UpdateCurveValue(i,xVal,yVal)
	self.m_curve:UpdateCurveValue(i,xVal,yVal)
	self:UpdateDataPoints(i +1)
end
function gui.PFMTimelineCurve:SetHorizontalRange(...)
	self.m_curve:SetHorizontalRange(...)
	self:UpdateDataPoints()
end
function gui.PFMTimelineCurve:SetVerticalRange(...)
	self.m_curve:SetVerticalRange(...)
	self:UpdateDataPoints()
end
gui.register("WIPFMTimelineCurve",gui.PFMTimelineCurve)

----------------

util.register_class("gui.PFMTimelineGraph",gui.Base)

gui.PFMTimelineGraph.CURSOR_MODE_SELECT = 0
gui.PFMTimelineGraph.CURSOR_MODE_MOVE = 1
gui.PFMTimelineGraph.CURSOR_MODE_PAN = 2
gui.PFMTimelineGraph.CURSOR_MODE_SCALE = 3
gui.PFMTimelineGraph.CURSOR_MODE_ZOOM = 4
function gui.PFMTimelineGraph:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(512,256)
	self.m_bg = gui.create("WIRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_bg:SetColor(Color(128,128,128))

	self.m_grid = gui.create("WIGrid",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)

	self.m_graphContainer = gui.create("WIBase",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	
	local listContainer = gui.create("WIRect",self,0,0,204,self:GetHeight(),0,0,0,1)
	listContainer:SetColor(Color(38,38,38))

	self.m_scrollContainer = gui.create("WIScrollContainer",listContainer,0,0,listContainer:GetWidth(),listContainer:GetHeight(),0,0,1,1)

	self.m_transformList = gui.create("WIPFMTreeView",self.m_scrollContainer,0,0,self.m_scrollContainer:GetWidth(),self.m_scrollContainer:GetHeight())
	self.m_transformList:SetSelectable(gui.Table.SELECTABLE_MODE_MULTI)

	local dataAxisStrip = gui.create("WILabelledTimelineStrip",self,listContainer:GetRight(),0,20,self:GetHeight(),0,0,0,1)
	dataAxisStrip:SetHorizontal(false)
	dataAxisStrip:SetDataAxisInverted(true)
	dataAxisStrip:AddDebugMarkers()
	-- dataAxisStrip:SetFlipped(true)
	self.m_dataAxisStrip = dataAxisStrip

	self.m_keys = {}

	self.m_graphs = {}
	self.m_channelPathToGraphIndices = {}
	self.m_timeAxis = util.GraphAxis()
	self.m_dataAxis = util.GraphAxis()

	dataAxisStrip:SetAxis(self.m_dataAxis)

	self:SetCursorMode(gui.PFMTimelineGraph.CURSOR_MODE_SELECT)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self:SetScrollInputEnabled(true)
	-- gui.set_mouse_selection_enabled(self,true)

	local animManager = pfm.get_project_manager():GetAnimationManager()
	self.m_cbOnChannelValueChanged = animManager:AddCallback("OnChannelValueChanged",function(data)
		if(self.m_skipOnChannelValueChangedCallback == true) then return end
		self:UpdateChannelValue(data)
	end)
	self.m_cbOnKeyframeUpdated = animManager:AddCallback("OnKeyframeUpdated",function(data)
		if(self.m_skipOnChannelValueChangedCallback == true) then return end
		self:UpdateChannelValue(data)
	end)
end
function gui.PFMTimelineGraph:ReloadGraphCurveSegment(i,keyIndex)
	local graphData = self.m_graphs[i]

	local function updateSegment(keyIndex)
		local dp0 = graphData.curve.m_dataPoints[keyIndex +1]
		local dp1 = graphData.curve.m_dataPoints[keyIndex +2]
		if(dp0 == nil or dp1 == nil) then return end
		self.m_skipUpdateChannelValue = true
		self:InitializeCurveDataValues(dp0,dp1)
		self.m_skipUpdateChannelValue = nil
	end
	updateSegment(keyIndex -1)
	updateSegment(keyIndex)

	self:RebuildGraphCurve(i,graphData,true) -- TODO: Only when needed
end
function gui.PFMTimelineGraph:UpdateChannelValue(data)
	if(self.m_skipUpdateChannelValue) then return end
	local udmChannel = data.udmChannel
	local indices = self.m_channelPathToGraphIndices[udmChannel:GetTargetPath()]
	if(indices == nil) then return end
	for _,i in ipairs(indices) do
		local graphData = self.m_graphs[i]
		if(graphData.curve:IsValid()) then
			local editorKeys = graphData.curve:GetEditorKeys()
			if(editorKeys == nil or graphData.numValues ~= editorKeys:GetTimeCount()) then
				-- Number of keyframe keys has changed, we'll have to rebuild the entire curve
				self:RebuildGraphCurve(i,graphData)

				editorKeys = graphData.curve:GetEditorKeys()
				graphData.numValues = (editorKeys ~= nil) and editorKeys:GetTimeCount() or 0
			elseif(data.fullUpdateRequired) then
				self:RebuildGraphCurve(i,graphData,true)
			elseif(data.keyIndex ~= nil) then
				-- We only have to rebuild the two curve segments connected to the key
				self:ReloadGraphCurveSegment(i,data.keyIndex)

				-- Also update key data point position
				if(data.oldKeyIndex ~= nil) then
					self:ReloadGraphCurveSegment(i,data.oldKeyIndex)
					graphData.curve:SwapDataPoints(data.oldKeyIndex,data.keyIndex)
					graphData.curve:UpdateDataPoints()
				else graphData.curve:UpdateDataPoint(data.keyIndex +1) end
			end
		end
	end
end
function gui.PFMTimelineGraph:GetTimeAxisExtents() return self:GetWidth() end
function gui.PFMTimelineGraph:GetDataAxisExtents() return self.m_dataAxisStrip:GetHeight() end
function gui.PFMTimelineGraph:OnRemove()
	util.remove(self.m_cbOnChannelValueChanged)
	util.remove(self.m_cbOnKeyframeUpdated)
	util.remove(self.m_cbDataAxisPropertiesChanged)
end
function gui.PFMTimelineGraph:KeyboardCallback(key,scanCode,state,mods)
	if(key == input.KEY_DELETE) then
		if(state == input.STATE_PRESS) then
			local dps = self:GetSelectedDataPoints()
			-- Need to sort by value index, otherwise the value indices could change while we're deleting
			table.sort(dps,function(a,b) return a:GetValueIndex() > b:GetValueIndex() end)
			self.m_skipOnChannelValueChangedCallback = true
			for _,dp in ipairs(dps) do
				local actor,targetPath,valueIndex,curveData = dp:GetChannelValueData()
				local pm = pfm.get_project_manager()
				local animManager = pm:GetAnimationManager()
				animManager:RemoveChannelValueByIndex(actor,targetPath,valueIndex)
			end
			self.m_skipOnChannelValueChangedCallback = nil
			self:RebuildGraphCurves()
		end
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_1) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_2) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_3) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_4) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_5) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_6) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_7) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	elseif(key == input.KEY_8) then
		print("Not yet implemented!")
		return util.EVENT_REPLY_HANDLED
	end
	return util.EVENT_REPLY_UNHANDLED
end
function gui.PFMTimelineGraph:GetSelectedDataPoints(includeHandles,includePointsIfHandleSelected)
	if(includeHandles == nil) then includeHandles = true end
	includePointsIfHandleSelected = includePointsIfHandleSelected or false
	local dps = {}
	for _,graphData in ipairs(self.m_graphs) do
		if(graphData.curve:IsValid()) then
			local cdps = graphData.curve:GetDataPoints()
			for _,dp in ipairs(cdps) do
				if(dp:IsValid()) then
					if(dp:IsSelected() or (includePointsIfHandleSelected and dp:IsHandleSelected())) then table.insert(dps,dp) end
					local tc = dp:GetTangentControl()
					if(util.is_valid(tc) and includeHandles == true) then
						local inC = tc:GetInControl()
						if(inC:IsSelected()) then table.insert(dps,inC) end

						local outC = tc:GetOutControl()
						if(outC:IsSelected()) then table.insert(dps,outC) end
					end
				end
			end
		end
	end
	return dps
end
function gui.PFMTimelineGraph:MouseCallback(button,state,mods)
	self:RequestFocus()

	local isCtrlDown = input.is_ctrl_key_down()
	local isAltDown = input.is_alt_key_down()
	local cursorMode = self:GetCursorMode()
	if(button == input.MOUSE_BUTTON_LEFT) then
		if(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_MOVE) then
			local moveEnabled = (state == input.STATE_PRESS)
			for _,dp in ipairs(self:GetSelectedDataPoints()) do
				dp:SetMoveModeEnabled(moveEnabled)
			end
		elseif(state == input.STATE_PRESS) then
			local timeAxis = self.m_timeline:GetTimeline():GetTimeAxis():GetAxis()
			local dataAxis = self.m_timeline:GetTimeline():GetDataAxis():GetAxis()
			self.m_cursorTracker = {
				tracker = gui.CursorTracker(),
				timeAxisStartOffset = timeAxis:GetStartOffset(),
				timeAxisZoomLevel = timeAxis:GetZoomLevel(),
				dataAxisStartOffset = dataAxis:GetStartOffset(),
				dataAxisZoomLevel = dataAxis:GetZoomLevel()
			}
			self:EnableThinking()

			if(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_SELECT) then
				if(util.is_valid(self.m_selectionRect) == false) then
					self.m_selectionRect = gui.create("WISelectionRect",self.m_graphContainer)
					self.m_selectionRect:SetPos(self.m_graphContainer:GetCursorPos())
				end
			end
		else
			if(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_SELECT) then
				if(util.is_valid(self.m_selectionRect)) then
					for _,graphData in ipairs(self.m_graphs) do
						if(graphData.curve:IsValid()) then
							local dps = graphData.curve:GetDataPoints()
							for _,dp in ipairs(dps) do
								if(dp:UpdateSelection(self.m_selectionRect) == false and isCtrlDown == false and isAltDown == false) then
									dp:SetSelected(false)
								end
							end
						end
					end
					-- TODO: Select or deselect all points on curve if no individual points are within the select bounds, but the curve is
				end
			end

			self.m_cursorTracker = nil
			util.remove(self.m_selectionRect)
			self:DisableThinking()
		end
		return util.EVENT_REPLY_HANDLED
	elseif(button == input.MOUSE_BUTTON_RIGHT) then
		local isCtrlDown = input.get_key_state(input.KEY_LEFT_CONTROL) ~= input.STATE_RELEASE or
			input.get_key_state(input.KEY_RIGHT_CONTROL) ~= input.STATE_RELEASE
		local isAltDown = input.get_key_state(input.KEY_LEFT_ALT) ~= input.STATE_RELEASE or
			input.get_key_state(input.KEY_RIGHT_ALT) ~= input.STATE_RELEASE
		if(isCtrlDown) then
			print("Not yet implemented!")
		elseif(isAltDown) then
			print("Not yet implemented!")
		elseif(state == input.STATE_PRESS) then
			local pContext = gui.open_context_menu()
			if(util.is_valid(pContext) == false) then return end
			pContext:SetPos(input.get_cursor_pos())

			local schema = pfm.udm.get_schema()

			local function get_enum_set(name)
				local enums = schema:GetEnumSet(name)
				local indexToName = {}
				for k,v in pairs(enums) do
					local name = k
					local normName = ""
					for i=1,#name do
						if(name:sub(i,i) == name:sub(i,i):upper()) then normName = normName .. "_" .. name:sub(i,i):lower()
						else normName = normName .. name:sub(i,i) end
					end
					indexToName[v +1] = normName
				end
				return indexToName
			end

			local pItem,pSubMenuInterp = pContext:AddSubMenu(locale.get_text("pfm_graph_editor_interpolation"))
			local esInterpolation = get_enum_set("Interpolation")
			for val,name in ipairs(esInterpolation) do
				val = val -1
				pSubMenuInterp:AddItem(locale.get_text("pfm_graph_editor_interpolation_" .. name),function()
					local timeline = self:GetTimeline()
					timeline:SetInterpolationMode(val)
				end)
			end
			pSubMenuInterp:Update()

			local pItem,pSubMenuInterp = pContext:AddSubMenu(locale.get_text("pfm_graph_editor_easing_mode"))
			local esEasing = get_enum_set("EasingMode")
			for val,name in ipairs(esEasing) do
				val = val -1
				pSubMenuInterp:AddItem(locale.get_text("pfm_graph_editor_easing_mode_" .. name),function()
					local timeline = self:GetTimeline()
					timeline:SetEasingMode(val)
				end)
			end
			pSubMenuInterp:Update()

			pContext:Update()
			return util.EVENT_REPLY_HANDLED
		end
	elseif(button == input.MOUSE_BUTTON_MIDDLE) then
		local isAltDown = input.get_key_state(input.KEY_LEFT_ALT) ~= input.STATE_RELEASE or
			input.get_key_state(input.KEY_RIGHT_ALT) ~= input.STATE_RELEASE
		if(isAltDown) then
			print("Not yet implemented!")
		else
			print("Not yet implemented!")
		end
	end
	return util.EVENT_REPLY_UNHANDLED
end
function gui.PFMTimelineGraph:OnThink()
	if(self.m_cursorTracker == nil) then return end
	local trackerData = self.m_cursorTracker
	local tracker = trackerData.tracker
	local dt = tracker:Update()
	if(dt.x == 0 and dt.y == 0) then return end

	local dtPos = tracker:GetTotalDeltaPosition()
	local timeLine = self.m_timeline:GetTimeline()

	local cursorMode = self:GetCursorMode()
	if(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_SELECT) then

	elseif(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_MOVE) then

	elseif(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_PAN) then
		timeLine:GetTimeAxis():GetAxis():SetStartOffset(trackerData.timeAxisStartOffset -timeLine:GetTimeAxis():GetAxis():XDeltaToValue(dtPos).x)
		timeLine:GetDataAxis():GetAxis():SetStartOffset(trackerData.dataAxisStartOffset +timeLine:GetDataAxis():GetAxis():XDeltaToValue(dtPos).y)
		timeLine:Update()
	elseif(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_SCALE) then
	elseif(cursorMode == gui.PFMTimelineGraph.CURSOR_MODE_ZOOM) then
		timeLine:GetTimeAxis():GetAxis():SetZoomLevel(trackerData.timeAxisZoomLevel +dtPos.x /100.0)
		timeLine:GetDataAxis():GetAxis():SetZoomLevel(trackerData.dataAxisZoomLevel +dtPos.y /100.0)
		timeLine:Update()
	end
end
function gui.PFMTimelineGraph:ScrollCallback(x,y)
	local isCtrlDown = input.get_key_state(input.KEY_LEFT_CONTROL) ~= input.STATE_RELEASE or
		input.get_key_state(input.KEY_RIGHT_CONTROL) ~= input.STATE_RELEASE
	if(isCtrlDown) then
		local timeLine = self.m_timeline:GetTimeline()
		local axis = timeLine:GetDataAxis():GetAxis()
		axis:SetZoomLevel(axis:GetZoomLevel() -(y /20.0))
		timeLine:Update()

		self:UpdateAxisRanges(axis:GetStartOffset(),axis:GetZoomLevel())
		return util.EVENT_REPLY_HANDLED
	end
	return util.EVENT_REPLY_UNHANDLED
end
function gui.PFMTimelineGraph:SetCursorMode(cursorMode) self.m_cursorMode = cursorMode end
function gui.PFMTimelineGraph:GetCursorMode() return self.m_cursorMode end
function gui.PFMTimelineGraph:SetTimeline(timeline) self.m_timeline = timeline end
function gui.PFMTimelineGraph:GetTimeline() return self.m_timeline end
function gui.PFMTimelineGraph:SetTimeAxis(timeAxis) self.m_timeAxis = timeAxis end
function gui.PFMTimelineGraph:SetDataAxis(dataAxis)
	self.m_dataAxis = dataAxis
	self.m_dataAxisStrip:SetAxis(dataAxis:GetAxis())

	util.remove(self.m_cbDataAxisPropertiesChanged)
	self.m_cbDataAxisPropertiesChanged = dataAxis:GetAxis():AddCallback("OnPropertiesChanged",function()
		self.m_dataAxisStrip:Update()
	end)
end
function gui.PFMTimelineGraph:GetTimeAxis() return self.m_timeAxis end
function gui.PFMTimelineGraph:GetDataAxis() return self.m_dataAxis end
function gui.PFMTimelineGraph:UpdateGraphCurveAxisRanges(i)
	local graphData = self.m_graphs[i]
	local graph = graphData.curve
	if(graph:IsValid() == false) then return end
	local timeAxis = self:GetTimeAxis():GetAxis()
	local timeRange = {timeAxis:GetStartOffset(),timeAxis:XOffsetToValue(self:GetRight())}
	graph:SetHorizontalRange(timeRange[1],timeRange[2])

	local dataAxis = self:GetDataAxis():GetAxis()
	local dataRange = {dataAxis:GetStartOffset(),dataAxis:XOffsetToValue(self:GetBottom())}
	graph:SetVerticalRange(dataRange[1],dataRange[2])
end
function gui.PFMTimelineGraph:RebuildGraphCurves()
	for i=1,#self.m_graphs do
		local graphData = self.m_graphs[i]
		if(graphData.curve:IsValid()) then
			self:RebuildGraphCurve(i,graphData)
		end
	end
end

function gui.PFMTimelineGraph:InitializeCurveDataValues(dp0,dp1)
	if(dp0 == nil or dp1 == nil) then return end
	local actor0,targetPath0,keyIndex0,curveData0 = dp0:GetChannelValueData()
	local actor1,targetPath1,keyIndex1,curveData1 = dp1:GetChannelValueData()
	assert(actor0 == actor1 and targetPath0 == targetPath1 and curveData0 == curveData1)

	local pm = pfm.get_project_manager()
	local animManager = pm:GetAnimationManager()

	local curve = dp0:GetGraphCurve()
	local editorChannel = curve:GetEditorChannel()
	if(editorChannel == nil) then return end

	local editorGraphCurve = editorChannel:GetGraphCurve()
	local editorKeys = editorGraphCurve:GetKey(dp0:GetTypeComponentIndex())

	local interpMethod = editorKeys:GetInterpolationMode(keyIndex0)
	local easingMode = editorKeys:GetEasingMode(keyIndex0)

	local panimaChannel = curve:GetPanimaChannel()
	local anim,channel,animClip = animManager:FindAnimationChannel(actor0,targetPath0)
	local valueIndex0 = panimaChannel:FindIndex(editorKeys:GetTime(keyIndex0),pfm.udm.EditorChannelData.TIME_EPSILON)
	local valueIndex1 = panimaChannel:FindIndex(editorKeys:GetTime(keyIndex1),pfm.udm.EditorChannelData.TIME_EPSILON)
	if(valueIndex0 == nil) then
		valueIndex0 = panimaChannel:AddValue(editorKeys:GetTime(keyIndex0),editorKeys:GetValue(keyIndex0))
	end
	if(valueIndex1 == nil) then
		valueIndex1 = panimaChannel:AddValue(editorKeys:GetTime(keyIndex1),editorKeys:GetValue(keyIndex1))
	end
	if(valueIndex0 == nil or valueIndex1 == nil) then
		local key = (valueIndex0 == nil) and keyIndex0 or keyIndex1
		pfm.log("Animation graph key " .. key .. " at timestamp " .. editorKeys:GetTime(key) .. " has no associated animation data value!",pfm.LOG_CATEGORY_PFM,pfm.LOG_SEVERITY_WARNING)
		-- return
	end

	-- Ensure that animation values at keyframe timestamps match the keyframe values
	channel:SetValue(valueIndex0,editorKeys:GetValue(keyIndex0))
	channel:SetValue(valueIndex1,editorKeys:GetValue(keyIndex1))
	--

	if(interpMethod == pfm.udm.INTERPOLATION_CONSTANT) then
		local result,valueIndex1 = animManager:SetCurveChannelValueCount(actor0,targetPath0,valueIndex0,valueIndex1,1)
		if(result) then
			local anim,channel,animClip = animManager:FindAnimationChannel(actor0,targetPath0)
			channel:SetValue(valueIndex0 +1,channel:GetValue(valueIndex0))
			channel:SetTime(valueIndex0 +1,channel:GetTime(valueIndex1) -0.001)
		end
	elseif(interpMethod == pfm.udm.INTERPOLATION_LINEAR) then
		local result,valueIndex1 = animManager:SetCurveChannelValueCount(actor0,targetPath0,valueIndex0,valueIndex1,0)
	else
		local begin
		local duration = 1
		local change

		local calcPointOnCurve
		if(interpMethod == pfm.udm.INTERPOLATION_BEZIER) then
			calcPointOnCurve = function(t,normalizedTime,dt,cp0Time,cp0Val,cp0OutTime,cp0OutVal,cp1InTime,cp1InVal,cp1Time,cp1Val) return math.calc_bezier_point(t,cp0Time,cp0Val,cp0OutTime,cp0OutVal,cp1InTime,cp1InVal,cp1Time,cp1Val) end
		else
			local easingMethod = pfm.util.get_easing_method(interpMethod,easingMode)
			calcPointOnCurve = function(t,normalizedTime,dt,cp0Time,cp0Val,cp0OutTime,cp0OutVal,cp1InTime,cp1InVal,cp1Time,cp1Val) return easingMethod(normalizedTime,begin,change,duration) end
		end

		local anim,channel,animClip = animManager:FindAnimationChannel(actor0,targetPath0)

		local cp0Time = editorKeys:GetTime(keyIndex0)
		local cp0Val = editorKeys:GetValue(keyIndex0)

		local cp1Time = editorKeys:GetTime(keyIndex1)
		local cp1Val = editorKeys:GetValue(keyIndex1)

		local cp0OutTime = editorKeys:GetOutTime(keyIndex0)
		local cp0OutVal = editorKeys:GetOutDelta(keyIndex0)
		cp0OutTime = math.min(cp0Time +cp0OutTime,cp1Time -0.0001)
		cp0OutVal = cp0Val +cp0OutVal

		local cp1InTime = editorKeys:GetInTime(keyIndex1)
		local cp1InVal = editorKeys:GetInDelta(keyIndex1)

		cp1InTime = math.max(cp1Time +cp1InTime,cp0Time +0.0001)
		cp1InVal = cp1Val +cp1InVal

		begin = cp0Val
		change = cp1Val -cp0Val

		local function denormalize_time(normalizedTime) return cp0Time +(cp1Time -cp0Time) *normalizedTime end
		local function calc_point(normalizedTime,dt)
			if(normalizedTime == 0.0) then return Vector2(normalizedTime,cp0Val)
			elseif(normalizedTime == 1.0) then return Vector2(normalizedTime,cp1Val) end
			local t = denormalize_time(normalizedTime)
			return Vector2(normalizedTime,calcPointOnCurve(
				t,normalizedTime,dt,
				cp0Time,cp0Val,
				cp0OutTime,cp0OutVal,
				cp1InTime,cp1InVal,
				cp1Time,cp1Val
			))
			--return Vector2(normalizedTime,math.lerp(cp0Val,cp1Val,normalizedTime))
		end

		--
		-- We want to take a bunch of data samples on the bezier curve
		-- to fill our animation channel with. The more samples we use, the more accurately it will match
		-- the path of the original curve, but at the cost of memory. To reduce the number of samples we need, we create
		-- a sparse distribution at straight curve segments, and a tight distribution at segments with steep angles.
		local maxStepCount = 100 -- Number of samples will never exceed this value
		local dt = 1.0 /(maxStepCount -1)
		local timeValues = {calc_point(0.0,dt)}
		local startPoint = calc_point(0.0,dt)
		local endPoint = calc_point(1.0,dt)
		local prevPoint = startPoint
		local n = (endPoint -startPoint):GetNormal()
		for i=1,maxStepCount -2 do
			local t = i *dt
			local point = calc_point(t,dt)
			local nToPoint = (point -prevPoint):GetNormal()
			local dot = n:DotProduct(nToPoint)
			if(dot < 0.995) then -- Only create a sample for this point if it deviates from a straight line to the previous sample (i.e. if linear interpolation would be insufficient)
				table.insert(timeValues,point)
				n = nToPoint
			end

			prevPoint = point
		end

		-- First and last values are already defined by keyframes
		table.remove(timeValues,1)
		-- table.insert(timeValues,calc_point(1.0,dt))
		--

		local numValues = #timeValues
		local result,valueIndex1 = animManager:SetCurveChannelValueCount(actor0,targetPath0,valueIndex0,valueIndex1,numValues)
		if(result) then
			for i,tv in ipairs(timeValues) do
				assert((i == 1 or tv.x > 0.0) and (i == #timeValues or tv.x < 1.0))
				channel:SetTime(valueIndex0 +i,denormalize_time(tv.x))
				channel:SetValue(valueIndex0 +i,tv.y)
			end
		end
	end
end
function gui.PFMTimelineGraph:RebuildGraphCurve(i,graphData,updateCurveOnly)
	local channel = graphData.channel()
	if(channel == nil) then return end
	local times = channel:GetTimes()
	local values = channel:GetValues()

	local graphData = self.m_graphs[i]
	local curveValues = {}
	for i=1,#times do
		local t = times[i]
		local v = values[i]
		v = (graphData.valueTranslator ~= nil) and graphData.valueTranslator[1](v) or v
		table.insert(curveValues,{t,v})
	end

	if(updateCurveOnly) then
		graphData.curve:UpdateCurveData(curveValues)
		return
	end

	local targetPath = channel:GetTargetPath()
	local animClip = graphData.animClip()
	if(animClip ~= nil) then
		local editorData = animClip:GetEditorData()
		local channel = editorData:FindChannel(targetPath)
		graphData.editorChannel = channel
		if(channel ~= nil) then
			local bms = channel:GetBookmarkSet()
			graphData.bookmarkSet = bms
			self.m_timeline:AddBookmarkSet(bms)
		end
	end
	graphData.curve:BuildCurve(curveValues,channel,i,graphData.editorChannel,graphData.typeComponentIndex)
end
function gui.PFMTimelineGraph:RemoveGraphCurve(i)
	local graphData = self.m_graphs[i]
	if(graphData.bookmarkSet ~= nil) then self.m_timeline:RemoveBookmarkSet(graphData.bookmarkSet) end
	util.remove(graphData.bookmarks)
	util.remove(graphData.curve)

	local graphIndices = self.m_channelPathToGraphIndices[graphData.targetPath]
	for j,ci in ipairs(graphIndices) do
		if(ci == i) then
			table.remove(graphIndices,j)
			break
		end
	end
	if(#graphIndices == 0) then self.m_channelPathToGraphIndices[graphData.targetPath] = nil end

	while(#self.m_graphs > 0 and not util.is_valid(self.m_graphs[#self.m_graphs].curve)) do
		table.remove(self.m_graphs,#self.m_graphs)
	end
end
function gui.PFMTimelineGraph:GetGraphCurve(i) return self.m_graphs[i] end
function gui.PFMTimelineGraph:AddGraph(track,actor,targetPath,colorCurve,fValueTranslator,valueType,typeComponentIndex)
	if(util.is_valid(self.m_graphContainer) == false) then return end

	local graph = gui.create("WIPFMTimelineCurve",self.m_graphContainer,0,0,self.m_graphContainer:GetWidth(),self.m_graphContainer:GetHeight(),0,0,1,1)
	graph:SetTimelineGraph(self)
	graph:SetColor(colorCurve)
	local animClip
	local function getAnimClip()
		animClip = animClip or track:FindActorAnimationClip(actor)
		return animClip
	end
	getAnimClip()
	local channel = (animClip ~= nil) and animClip:FindChannel(targetPath) or nil
	table.insert(self.m_graphs,{
		actor = actor,
		animClip = getAnimClip,
		channel = function()
			getAnimClip()
			channel = channel or ((animClip ~= nil) and animClip:FindChannel(targetPath) or nil)
			return channel
		end,
		curve = graph,
		valueTranslator = fValueTranslator,
		targetPath = targetPath,
		bookmarks = {},
		typeComponentIndex = typeComponentIndex or 0,
		valueType = valueType
	})
	self.m_channelPathToGraphIndices[targetPath] = self.m_channelPathToGraphIndices[targetPath] or {}
	table.insert(self.m_channelPathToGraphIndices[targetPath],#self.m_graphs)

	local idx = #self.m_graphs
	self:UpdateGraphCurveAxisRanges(idx)
	if(channel ~= nil) then self:RebuildGraphCurve(idx,self.m_graphs[idx]) end
	return graph,idx
end
function gui.PFMTimelineGraph:GetGraphs() return self.m_graphs end
function gui.PFMTimelineGraph:UpdateAxisRanges(startOffset,zoomLevel)
	if(util.is_valid(self.m_grid)) then
		self.m_grid:SetStartOffset(startOffset)
		self.m_grid:SetZoomLevel(zoomLevel)
		self.m_grid:Update()
	end
	for i=1,#self.m_graphs do
		self:UpdateGraphCurveAxisRanges(i)
	end
end
function gui.PFMTimelineGraph:SetupControl(filmClip,actor,targetPath,item,color,fValueTranslator,valueType,typeComponentIndex)
	local graph,graphIndex
	item:AddCallback("OnSelected",function()
		if(util.is_valid(graph)) then self:RemoveGraphCurve(graphIndex) end

		local track = filmClip:FindAnimationChannelTrack()
		if(track == nil) then return end
		graph,graphIndex = self:AddGraph(track,actor,targetPath,color,fValueTranslator,valueType,typeComponentIndex)
	end)
	item:AddCallback("OnDeselected",function()
		if(util.is_valid(graph)) then self:RemoveGraphCurve(graphIndex) end
	end)
end
function gui.PFMTimelineGraph:AddBookmarkDataPoint(time)
	if(util.is_valid(self.m_timeline) == false) then return end

	for _,graph in ipairs(self.m_graphs) do
		if(graph.curve:IsValid()) then
			local time = self.m_timeline:GetTimeOffset()
			local value = 0.0
			local valueType = graph.valueType
			local channel = graph.curve:GetPanimaChannel()
			if(channel ~= nil) then
				local idx0,idx1,factor = channel:FindInterpolationIndices(time)
				if(idx0 ~= nil) then
					local v0 = channel:GetValue(idx0)
					local v1 = channel:GetValue(idx1)
					value = math.lerp(v0,v1,factor)
				end
			end
			pfm.get_project_manager():SetActorAnimationComponentProperty(graph.actor,graph.targetPath,time,value,valueType)
		end
	end
end
function gui.PFMTimelineGraph:OnVisibilityChanged(visible)
	if(visible == false or util.is_valid(self.m_timeline) == false) then return end
	local timeline = self.m_timeline:GetTimeline()
	timeline:ClearBookmarks()
end
function gui.PFMTimelineGraph:AddControl(filmClip,actor,controlData,memberInfo,valueTranslator)
	local itemCtrl = self.m_transformList:AddItem(controlData.name)
	local function addChannel(item,fValueTranslator,color,typeComponentIndex)
		self:SetupControl(filmClip,actor,controlData.path,item,color or Color.Red,fValueTranslator,memberInfo.type,typeComponentIndex or 0)
	end
	if(udm.is_numeric_type(memberInfo.type)) then
		local valueTranslator
		if(memberInfo.type == udm.TYPE_BOOLEAN) then
			valueTranslator = {
				function(v) return v and 1.0 or 0.0 end,
				function(v) return (v >= 0.5) and true or false end
			}
		end
		addChannel(itemCtrl,valueTranslator)

		--[[local log = channel:GetLog()
		local layers = log:GetLayers()
		local layer = layers:Get(1) -- TODO: Which layer(s) are the bookmarks refering to?
		if(layer ~= nil) then
			local bookmarks = log:GetBookmarks()
			for _,bookmark in ipairs(bookmarks:GetTable()) do
				self:AddKey(bookmark)
				-- Get from layer
			end
		end]]
	elseif(udm.is_vector_type(memberInfo.type)) then
		local n = udm.get_numeric_component_count(memberInfo.type)
		assert(n < 5)
		local type = udm.get_class_type(memberInfo.type)
		local vectorComponents = {
			{"X",Color.Red},
			{"Y",Color.Lime},
			{"Z",Color.Aqua},
			{"W",Color.Magenta},
		}
		for i=0,n -1 do
			local vc = vectorComponents[i +1]
			addChannel(itemCtrl:AddItem(vc[1]),{
				function(v) return v:Get(i) end,
				function(v,curVal)
					local r = curVal:Copy()
					r:Set(i,v)
					return r
				end
			},vc[2],i)
		end
	elseif(udm.is_matrix_type(memberInfo.type)) then
		local nRows = udm.get_matrix_row_count(memberInfo.type)
		local nCols = udm.get_matrix_column_count(memberInfo.type)
		local type = udm.get_class_type(memberInfo.type)
		for i=0,nRows -1 do
			for j=0,nCols -1 do
				addChannel(itemCtrl:AddItem("M[" .. i .. "][" .. j .. "]"),{
					function(v) return v:Get(i,j) end,
					function(v,curVal)
						local r = curVal:Copy()
						r:Set(i,j,v)
						return r
					end
				},nil,i *nCols +j)
			end
		end
	elseif(memberInfo.type == udm.TYPE_EULER_ANGLES) then
		addChannel(itemCtrl:AddItem(locale.get_text("euler_pitch")),{
			function(v) return v.p end,
			function(v,curVal) return EulerAngles(v,curVal.y,curVal.r) end
		},Color.Red,0)
		addChannel(itemCtrl:AddItem(locale.get_text("euler_yaw")),{
			function(v) return v.y end,
			function(v,curVal) return EulerAngles(curVal.p,v,curVal.r) end
		},Color.Lime,1)
		addChannel(itemCtrl:AddItem(locale.get_text("euler_roll")),{
			function(v) return v.r end,
			function(v,curVal) return EulerAngles(curVal.p,curVal.y,v) end
		},Color.Aqua,2)
	elseif(memberInfo.type == udm.TYPE_QUATERNION) then
		addChannel(itemCtrl:AddItem(locale.get_text("euler_pitch")),{
			function(v) return v:ToEulerAngles().p end,
			function(v,curVal)
				local ang = curVal:ToEulerAngles()
				ang.p = v
				return ang:ToQuaternion()
			end
		},Color.Red,0)
		addChannel(itemCtrl:AddItem(locale.get_text("euler_yaw")),{
			function(v) return v:ToEulerAngles().y end,
			function(v,curVal)
				local ang = curVal:ToEulerAngles()
				ang.y = v
				return ang:ToQuaternion()
			end
		},Color.Lime,1)
		addChannel(itemCtrl:AddItem(locale.get_text("euler_roll")),{
			function(v) return v:ToEulerAngles().r end,
			function(v,curVal)
				local ang = curVal:ToEulerAngles()
				ang.r = v
				return ang:ToQuaternion()
			end
		},Color.Aqua,2)
	end
	if(controlData.type == "flexController") then
		if(controlData.dualChannel ~= true) then
			local property = controlData.getProperty(component)
			local channel = track:FindFlexControllerChannel(property)
			if(channel ~= nil) then
				addChannel(channel,itemCtrl)

				local log = channel:GetLog()
				local layers = log:GetLayers()
				local layer = layers:Get(1) -- TODO: Which layer(s) are the bookmarks refering to?
				if(layer ~= nil) then
					local bookmarks = log:GetBookmarks()
					for _,bookmark in ipairs(bookmarks:GetTable()) do
						self:AddKey(bookmark)
						-- Get from layer
					end
					--[[local graphCurve = channel:GetGraphCurve()
					local keyTimes = graphCurve:GetKeyTimes()
					local keyValues = graphCurve:GetKeyValues()
					local n = math.min(#keyTimes,#keyValues)
					for i=1,n do
						local t = keyTimes:Get(i)
						local v = keyValues:Get(i)
						self:AddKey(t,v)
					end]]
				end
			end
		else
			local leftProperty = controlData.getLeftProperty(component)
			local leftChannel = track:FindFlexControllerChannel(leftProperty)
			if(leftChannel ~= nil) then addChannel(leftChannel,itemCtrl:AddItem(locale.get_text("left"))) end

			local rightProperty = controlData.getRightProperty(component)
			local rightChannel = track:FindFlexControllerChannel(rightProperty)
			if(rightChannel ~= nil) then addChannel(rightChannel,itemCtrl:AddItem(locale.get_text("right"))) end
		end
	elseif(controlData.type == "bone") then
		local channel = track:FindBoneChannel(controlData.bone:GetTransform())
		-- TODO: Localization
		if(channel ~= nil) then
			addChannel(channel,itemCtrl:AddItem("Position X"),function(v) return v.x end)
			addChannel(channel,itemCtrl:AddItem("Position Y"),function(v) return v.y end)
			addChannel(channel,itemCtrl:AddItem("Position Z"),function(v) return v.z end)

			addChannel(channel,itemCtrl:AddItem("Rotation X"),function(v) return v:ToEulerAngles().p end)
			addChannel(channel,itemCtrl:AddItem("Rotation Y"),function(v) return v:ToEulerAngles().y end)
			addChannel(channel,itemCtrl:AddItem("Rotation Z"),function(v) return v:ToEulerAngles().r end)
		end
	end

	itemCtrl:AddCallback("OnSelected",function(elCtrl)
		for _,el in ipairs(elCtrl:GetItems()) do
			el:Select()
		end
	end)
	-- TODO: WHich layer?
	-- Log Type?
	--[[local layerType = logLayer:GetValues():GetValueType()
	--float log
	--local type = self:GetValues():GetValueType()
	if(layer ~= nil) then
		local label = locale.get_text("position")
		self:AddTransform(layer,itemCtrl,label .. " X",Color.Red,function(v) return v end)
		self:AddTransform(layer,itemCtrl,label .. " X",Color.Red,function(v) return v.x end)
		--Color(227,90,90)
		self:AddTransform(layer,itemCtrl,label .. " Y",Color.Lime,function(v) return v.y end)
		--Color(84,168,70)
		self:AddTransform(layer,itemCtrl,label .. " Z",Color.Blue,function(v) return v.z end)
		--Color(96,127,193)
	end

	self.m_transformList:Update()
	self.m_transformList:SizeToContents()
	self.m_transformList:SetWidth(204)]]
	return itemCtrl
end
--[[function gui.PFMTimelineGraph:Setup(actor,channelClip)
	local mdlC = actor:FindComponent("pfm_model")
	if(mdlC == nil or util.is_valid(self.m_boneList) == false) then return end

	for _,bone in ipairs(mdlC:GetBoneList():GetTable()) do
		bone = bone:GetTarget()
		local bonePosChannel
		local boneRotChannel
		for _,channel in ipairs(channelClip:GetChannels():GetTable()) do
			if(util.is_same_object(channel:GetToElement(),bone:GetTransform())) then
				if(channel:GetToAttribute() == "position") then bonePosChannel = channel end
				if(channel:GetToAttribute() == "rotation") then boneRotChannel = channel end
				if(bonePosChannel ~= nil and boneRotChannel ~= nil) then
					break
				end
			end
		end

		local itemBone = self.m_boneList:AddItem(bone:GetName())
		itemBone:AddCallback("OnSelected",function(elBone)
			for _,el in ipairs(elBone:GetItems()) do
				el:Select()
			end
		end)
		if(bonePosChannel ~= nil) then
			local log = bonePosChannel:GetLog()
			local layer = log:GetLayers():FindByName("vector3 log")
			if(layer ~= nil) then
				local label = locale.get_text("position")
				self:AddTransform(layer,itemBone,label .. " X",Color.Red,function(v) return v.x end)
				--Color(227,90,90)
				self:AddTransform(layer,itemBone,label .. " Y",Color.Lime,function(v) return v.y end)
				--Color(84,168,70)
				self:AddTransform(layer,itemBone,label .. " Z",Color.Blue,function(v) return v.z end)
				--Color(96,127,193)
			end
		end
		if(boneRotChannel ~= nil) then
			local log = boneRotChannel:GetLog()
			local layer = log:GetLayers():FindByName("quaternion log")
			if(layer ~= nil) then
				local label = locale.get_text("rotation")
				self:AddTransform(layer,itemBone,label .. " X",Color.Red,function(v) return v:ToEulerAngles().p end)
				self:AddTransform(layer,itemBone,label .. " Y",Color.Lime,function(v) return v:ToEulerAngles().y end)
				self:AddTransform(layer,itemBone,label .. " Z",Color.Blue,function(v) return v:ToEulerAngles().r end)
			end
		end
	end

	self.m_boneList:Update()
	self.m_boneList:SizeToContents()
	self.m_boneList:SetWidth(204)
end]]
gui.register("WIPFMTimelineGraph",gui.PFMTimelineGraph)
