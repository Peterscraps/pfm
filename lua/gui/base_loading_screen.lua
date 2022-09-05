--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

locale.load("pfm_loading.txt")

pfm = pfm or {}

pfm.show_base_loading_screen = function(enabled,title,logo,loadingText)
	util.remove(gui.get_base_element():FindChildByName("loading_screen"))
	if(enabled == false) then return end
	local elBase = gui.create("WIBase")
	elBase:SetSize(1024,768)

	local fontSet = engine.get_default_font_set_name()
	local fontFeatures = bit.bor(engine.FONT_FEATURE_FLAG_SANS_BIT,engine.FONT_FEATURE_FLAG_MONO_BIT)
	engine.create_font("loading_main",fontSet,fontFeatures,60)

	engine.create_font("loading_small",fontSet,fontFeatures,14)

	local el = gui.create("WITexturedRect",elBase,0,0,elBase:GetWidth(),elBase:GetHeight(),0,0,1,1)
	el:SetMaterial("pfm/logo/bg_gradient")

	local elLogo = gui.create("WITexturedRect",elBase)
	elLogo:SetSize(220,220)
	elLogo:SetPos(120,256)
	elLogo:SetAnchor(0.5,0.5,0.5,0.5)

	local elTitle = gui.create("WIText",elBase)
	elTitle:SetColor(Color.White)
	elTitle:SetFont("loading_main")
	elTitle:SetText("title")
	elTitle:SizeToContents()
	elTitle:SizeToContents()
	elTitle:SetHeight(elTitle:GetHeight() +20)
	elTitle:SetPos(380,300)
	elTitle:SetAnchor(0.5,0.5,0.5,0.5)

	local elText = gui.create("WIText",elBase)
	elText:SetText(locale.get_text("pfm_loading"))
	elText:SetColor(Color.White)
	elText:SetFont("loading_small")
	elText:SizeToContents()
	elText:SetPos(380,elTitle:GetBottom() +30)
	elText:SetAnchor(0.5,0.5,0.5,0.5)
	elText:SetHeight(elText:GetHeight() +10)

	elBase:SetZPos(10000)
	elBase:SetName("loading_screen")

	local b = gui.get_base_element()
	elBase:SetSize(b:GetWidth(),b:GetHeight())
	elBase:SetAnchor(0,0,1,1)

	-- Init
	elTitle:SetText(title)
	elTitle:SizeToContents()
	elTitle:SetHeight(elTitle:GetHeight() +20)
	elLogo:SetMaterial(logo)

	if(loadingText ~= nil) then
		elText:SetText(loadingText)
		elText:SizeToContents()
		elText:SetHeight(elText:GetHeight() +10)
	end

	return elBase
end
