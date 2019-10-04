util.register_class("gui.PFMRenderPreviewWindow")
function gui.PFMRenderPreviewWindow:__init(parent)
	local frame = gui.create("WIFrame",parent)
	frame:SetTitle(locale.get_text("pfm_render_preview"))

	local margin = 10
	local tex = gui.create("WITexturedRect",frame)
	tex:SetSize(256,256)
	tex:SetPos(margin,24)
	self.m_preview = tex

	frame:SetWidth(tex:GetRight() +margin)
	frame:SetHeight(tex:GetBottom() +margin *2)
	frame:SetResizeRatioLocked(true)
	frame:SetPos(10,256)
	tex:SetAnchor(0,0,1,1)
	self.m_previewFrame = frame
	frame:AddCallback("Think",function()
		self:OnThink()
	end)

	local raytracingProgressBar = gui.create("WIProgressBar",frame)
	raytracingProgressBar:SetSize(tex:GetWidth(),10)
	raytracingProgressBar:SetPos(tex:GetLeft(),tex:GetBottom())
	raytracingProgressBar:SetColor(Color.Lime)
	raytracingProgressBar:SetVisible(false)
	raytracingProgressBar:SetAnchor(0,1,1,1)
	self.m_raytracingProgressBar = raytracingProgressBar

	local btRefresh = gui.create("WITexturedRect",frame)
	btRefresh:SetMaterial("gui/pfm/refresh")
	btRefresh:SetSize(12,12)
	btRefresh:SetTop(5)
	local elTitle = frame:FindDescendantByName("frame_title")
	if(elTitle ~= nil) then btRefresh:SetLeft(elTitle:GetRight() +5) end
	btRefresh:SetMouseInputEnabled(true)
	btRefresh:AddCallback("OnMousePressed",function()
		self:Refresh()
	end)
end
function gui.PFMRenderPreviewWindow:OnThink()
	if(self.m_raytracingJob == nil) then return end
	local progress = self.m_raytracingJob:GetProgress()
	if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetProgress(progress) end
	if(self.m_raytracingJob:IsComplete() == false) then return end
	if(self.m_raytracingJob:IsSuccessful()) then
		local imgBuffer = self.m_raytracingJob:GetResult()
		local img = vulkan.create_image(imgBuffer)
		local tex = vulkan.create_texture(img,vulkan.TextureCreateInfo(),vulkan.ImageViewCreateInfo(),vulkan.SamplerCreateInfo())
		
		if(util.is_valid(self.m_preview)) then self.m_preview:SetTexture(tex) end
		if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetVisible(false) end
	end
	self.m_raytracingJob = nil
end
function gui.PFMRenderPreviewWindow:Refresh()
	if(self.m_raytracingJob ~= nil) then self.m_raytracingJob:Cancel() end
	local job = util.capture_raytraced_screenshot(512,512,4)
	job:Start()
	self.m_raytracingJob = job

	if(util.is_valid(self.m_raytracingProgressBar)) then self.m_raytracingProgressBar:SetVisible(true) end
end
function gui.PFMRenderPreviewWindow:Remove()
	if(self.m_raytracingJob ~= nil) then self.m_raytracingJob:Cancel() end
	if(util.is_valid(self.m_previewFrame)) then self.m_previewFrame:Remove() end
end
function gui.PFMRenderPreviewWindow:IsValid()
	return util.is_valid(self.m_previewFrame)
end
