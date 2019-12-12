--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/pfm/fonts.lua")
include("/gui/wicontextmenu.lua")
include("/gui/pfm/sliderbar.lua")

util.register_class("gui.PFMSlider",gui.Base)

function gui.PFMSlider:__init()
	gui.Base.__init(self)
end
function gui.PFMSlider:OnInitialize()
	gui.Base.OnInitialize(self)

	self:SetSize(128,20)

	self.m_bg = gui.create("WIRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_bg:SetColor(Color(38,38,38))

	self.m_sliderBarUpper = gui.create("WIPFMSliderBar",self,0,3)
	self.m_sliderBarUpper:SetWidth(self:GetWidth())
	self.m_sliderBarUpper:SetAnchor(0,0,1,0)
	self.m_sliderBarUpper:AddCallback("OnValueChanged",function(el,value)
		self:CallCallbacks("OnLeftValueChanged",value)
	end)

	self.m_sliderBarLower = gui.create("WIPFMSliderBar",self,0,self.m_sliderBarUpper:GetBottom())
	self.m_sliderBarLower:SetWidth(self:GetWidth())
	self.m_sliderBarLower:SetAnchor(0,0,1,0)
	self.m_sliderBarLower:AddCallback("OnValueChanged",function(el,value)
		self:CallCallbacks("OnRightValueChanged",value)
	end)

	self.m_text = gui.create("WIText",self)
	self.m_text:SetColor(Color(182,182,182))
	self.m_text:SetFont("pfm_medium")
	self.m_text:SetVisible(false)

	self.m_outline = gui.create("WIOutlinedRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_outline:SetColor(Color(57,57,57))

	self:SetRange(0,1)
	self:SetLeftRightValueRatio(0.5)

	self:SetMouseInputEnabled(true)
	self:AddCallback("OnCursorMoved",function(el,x,y)
		self:OnCursorMoved(x,y)
	end)
end
function gui.PFMSlider:SetLeftRightValueRatio(ratio) self.m_leftRightRatio = math.clamp(ratio,0.0,1.0) end
function gui.PFMSlider:GetLeftRightValueRatio() return self.m_leftRightRatio end
function gui.PFMSlider:GetLeftSliderBar() return self.m_sliderBarUpper end
function gui.PFMSlider:GetRightSliderBar() return self.m_sliderBarLower end
function gui.PFMSlider:SetLeftRange(min,max,optDefault) local bar = self:GetLeftSliderBar() if(util.is_valid(bar)) then bar:SetRange(min,max,optDefault) end end
function gui.PFMSlider:SetRightRange(min,max,optDefault) local bar = self:GetRightSliderBar() if(util.is_valid(bar)) then bar:SetRange(min,max,optDefault) end end
function gui.PFMSlider:SetRange(min,max,optDefault)
	self:SetLeftRange(min,max,optDefault)
	self:SetRightRange(min,max,optDefault)
end
function gui.PFMSlider:SetLeftValue(value) local bar = self:GetLeftSliderBar() if(util.is_valid(bar)) then bar:SetValue(value) end end
function gui.PFMSlider:SetRightValue(value) local bar = self:GetRightSliderBar() if(util.is_valid(bar)) then bar:SetValue(value) end end
function gui.PFMSlider:SetValue(optValue)
	self:SetLeftValue(optValue)
	self:SetRightValue(optValue)
end
function gui.PFMSlider:GetLeftMin(value) local bar = self:GetLeftSliderBar() return util.is_valid(bar) and bar:GetMin() or 0.0 end
function gui.PFMSlider:GetRightMin(value) local bar = self:GetRightSliderBar() return util.is_valid(bar) and bar:GetMin() or 0.0 end
function gui.PFMSlider:GetLeftMax(value) local bar = self:GetLeftSliderBar() return util.is_valid(bar) and bar:GetMax() or 0.0 end
function gui.PFMSlider:GetRightMax(value) local bar = self:GetRightSliderBar() return util.is_valid(bar) and bar:GetMax() or 0.0 end
function gui.PFMSlider:GetLeftDefault(value) local bar = self:GetLeftSliderBar() return util.is_valid(bar) and bar:GetDefault() or 0.0 end
function gui.PFMSlider:GetRightDefault(value) local bar = self:GetRightSliderBar() return util.is_valid(bar) and bar:GetDefault() or 0.0 end
function gui.PFMSlider:GetLeftValue(value) local bar = self:GetLeftSliderBar() return util.is_valid(bar) and bar:GetValue() or 0.0 end
function gui.PFMSlider:GetRightValue(value) local bar = self:GetRightSliderBar() return util.is_valid(bar) and bar:GetValue() or 0.0 end
function gui.PFMSlider:GetMin() return self:GetLeftMin() end
function gui.PFMSlider:GetMax() return self:GetLeftMax() end
function gui.PFMSlider:GetDefault() return self:GetLeftDefault() end
function gui.PFMSlider:GetValue() return self:GetLeftValue() end
function gui.PFMSlider:OnRemove()
	self:EndMouseControl()
end
function gui.PFMSlider:EndMouseControl()
	if(self.m_lastCursorX == nil) then return end
	self:SetCursorMovementCheckEnabled(false)
	self.m_lastCursorX = nil
	gui.set_cursor_input_mode(gui.CURSOR_MODE_NORMAL)
end
function gui.PFMSlider:CreateSliderRangeEditWindow(min,max,default,fOnClose)
	local p = gui.create("WIPFMWindow")

	p:SetWindowSize(Vector2i(202,160))
	p:SetTitle(locale.get_text("pfm_slider_range_edit_window_title"))


	local contents = p:GetContents()

	gui.create("WIBase",contents,0,0,1,12) -- Gap

	local t = gui.create("WITable",contents)
	t:RemoveStyleClass("WITable")
	t:SetWidth(p:GetWidth() -13)
	t:SetRowHeight(28)

	local function add_text_field(name,value)
		local row = t:AddRow()
		row:SetValue(0,name)

		local textEntry = gui.create("WINumericEntry")
		textEntry:SetWidth(133)
		textEntry:SetText(value)
		row:InsertElement(1,textEntry)
		return textEntry
	end
	local teMin = add_text_field(locale.get_text("min") .. ":",tostring(min))
	local teMax = add_text_field(locale.get_text("max") .. ":",tostring(max))
	local teDefault = add_text_field(locale.get_text("default") .. ":",tostring(default))

	t:Update()
	t:SizeToContents()

	gui.create("WIBase",contents,0,0,1,3) -- Gap

	local boxButtons = gui.create("WIHBox",contents)

	local btOk = gui.create("WIButton",boxButtons)
	btOk:SetSize(73,21)
	btOk:SetText(locale.get_text("ok"))
	btOk:AddCallback("OnMousePressed",function()
		local min = util.is_valid(teMin) and tonumber(teMin:GetText()) or 0.0
		local max = util.is_valid(teMax) and tonumber(teMax:GetText()) or 0.0
		local default = util.is_valid(teDefault) and tonumber(teDefault:GetText()) or 0.0
		p:GetFrame():Remove()
		fOnClose(true,min,max,default)
	end)

	gui.create("WIBase",boxButtons,0,0,8,1) -- Gap

	local btCancel = gui.create("WIButton",boxButtons)
	btCancel:SetSize(73,21)
	btCancel:SetText(locale.get_text("cancel"))
	btCancel:AddCallback("OnMousePressed",function()
		p:GetFrame():Remove()
		fOnClose(false)
	end)

	boxButtons:Update()
	boxButtons:SetX(contents:GetWidth() -boxButtons:GetWidth())
	return p
end
function gui.PFMSlider:MouseCallback(button,state,mods)
	if(button == input.MOUSE_BUTTON_LEFT) then
		if(state == input.STATE_PRESS) then
			self:SetCursorMovementCheckEnabled(true)
			self.m_lastCursorX = self:GetCursorPos().x
			gui.set_cursor_input_mode(gui.CURSOR_MODE_HIDDEN)
		elseif(state == input.STATE_RELEASE) then
			self:EndMouseControl()
		end
	elseif(button == input.MOUSE_BUTTON_RIGHT and state == input.STATE_RELEASE) then
		local pContext = gui.open_context_menu()
		if(util.is_valid(pContext) == false) then return end
		pContext:SetPos(input.get_cursor_pos())
		local default = self:GetDefault()
		if(default ~= nil) then
			pContext:AddItem(locale.get_text("pfm_set_to_default"),function()
				if(self:IsValid() == false) then return end
				self:SetValue(self:GetDefault())
			end)
		end
		pContext:AddItem(locale.get_text("pfm_remap_slider_range"),function()
			self:CreateSliderRangeEditWindow(self:GetMin(),self:GetMax(),self:GetDefault(),function(ok,min,max,default)
				if(ok == true) then
					self:SetRange(min,max,default)
				end
			end)
		end)
		pContext:Update()
	end
	return util.EVENT_REPLY_HANDLED
end
function gui.PFMSlider:SetText(text)
	if(util.is_valid(self.m_text) == false) then return end
	self.m_text:SetVisible(#text > 0)
	self.m_text:SetText(text)
	self.m_text:SizeToContents()
	self.m_text:CenterToParent(true)
end
function gui.PFMSlider:OnCursorMoved(x,y)
	if(self.m_lastCursorX == nil) then return end
	local xDelta = x -self.m_lastCursorX
	self.m_lastCursorX = x

	local ratio = self:GetLeftRightValueRatio()
	local scaleRight = 0.0
	local scaleLeft = 0.0
	-- If ratio >= 0.5 -> left slider will be at full speed, otherwise right slider.
	-- Other slider will be scaled accordingly.
	if(ratio > 0.5) then
		scaleRight = 1.0
		scaleLeft = ((1.0 -ratio) /0.5)
	else
		scaleRight = ratio /0.5
		scaleLeft = 1.0
	end
	local fractionLeft = xDelta *scaleRight
	local fractionRight = xDelta *scaleLeft
	local leftValue = self:GetLeftValue() +self:GetLeftSliderBar():XToValue(fractionLeft)
	local rightValue = self:GetRightValue() +self:GetRightSliderBar():XToValue(fractionRight)
	self:SetLeftValue(leftValue)
	self:SetRightValue(rightValue)
end
gui.register("WIPFMSlider",gui.PFMSlider)
