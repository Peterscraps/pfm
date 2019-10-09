--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

pfm = pfm or {}
pfm.impl = pfm.impl or {}

pfm.impl.scenes = pfm.impl.scenes or {}

include("log.lua")
include("/udm/udm.lua")
include("udm")
include("tree/pfm_tree.lua")

util.register_class("pfm.Scene")
function pfm.Scene:__init()
  self.m_udmRoot = udm.create_element(udm.ELEMENT_TYPE_ROOT,"root")
end

function pfm.Scene:AddTrack(name)
  return self:GetUDMRootNode():CreateChild(udm.ELEMENT_TYPE_PFM_TRACK,name)
end

function pfm.Scene:GetUDMRootNode() return self.m_udmRoot end


pfm.create_scene = function()
  local scene = pfm.Scene()
  table.insert(pfm.impl.scenes,scene)
  return scene
end

pfm.get_scenes = function() return pfm.impl.scenes end
