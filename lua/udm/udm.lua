--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

udm = udm or {}

udm.impl = udm.impl or {}
udm.impl.registered_types = udm.impl.registered_types or {}
udm.impl.class_to_type_id = udm.impl.class_to_type_id or {}
udm.impl.name_to_type_id = udm.impl.name_to_type_id or {}
local registered_types = udm.impl.registered_types
local function register_type(className,baseClass,defaultArg,elementType)
  util.register_class("udm." .. className,baseClass)
  local class = udm[className]
  if(udm.impl.class_to_type_id[class] ~= nil) then return udm.impl.class_to_type_id[class] end
  function class:__init(arg)
    baseClass.__init(self,class,arg or defaultArg)
  end

  if(elementType) then
    function class:__tostring()
      return "UDMElement[" .. className .. "]"
    end
  else
    function class:__tostring()
      return self:GetStringValue()
    end
  end
  
  local typeId = #registered_types +1
  function class:GetType()
    return typeId
  end
  
  registered_types[typeId] = {
    class = class,
    typeName = className,
    isElement = elementType
  }
  if(elementType) then registered_types[typeId].properties = {} end
  udm.impl.class_to_type_id[class] = typeId
  udm.impl.name_to_type_id[className] = typeId
  return typeId
end

function udm.impl.get_type_data(typeId) return registered_types[typeId] end

function udm.get_type_name(typeId)
  if(registered_types[typeId] == nil) then return end
  return registered_types[typeId].typeName
end

function udm.get_type_id(typeName)
  return udm.impl.class_to_type_id[typeName]
end

function udm.register_attribute(className,defaultValue)
  return register_type(className,udm.BaseAttribute,defaultValue,false)
end

function udm.register_element(className)
  return register_type(className,udm.BaseElement,nil,true)
end

function udm.register_element_property(elType,propIdentifier,defaultValue)
  local elData = udm.impl.registered_types[elType]
  if(elData == nil or elData.isElement == false) then
    console.print_warning("Attempted to register property '" .. propIdentifier .. "' with element of type '" .. elType .. "', which is not a valid UDM element type!")
    return
  end
  local methodIdentifier = propIdentifier:sub(1,1):upper() .. propIdentifier:sub(2)
  elData.class["Get" .. methodIdentifier] = function(self) return self["m_" .. propIdentifier] end
  elData.class["Set" .. methodIdentifier] = function(self,value) self["m_" .. propIdentifier] = value end
  elData.properties[propIdentifier] = {
    getter = elData.class["Get" .. methodIdentifier],
    setter = elData.class["Set" .. methodIdentifier],
    defaultValue = defaultValue
  }
end

function udm.create(typeIdentifier,arg,shouldBeElement) -- Note: 'shouldBeElement' is for internal purposes only!
  if(type(typeIdentifier) == "string") then
    typeIdentifier = udm.get_type_id(typeIdentifier)
    if(typeIdentifier == nil) then return end
  end
  if(shouldBeElement == nil) then
    local elData = registered_types[typeIdentifier]
    return udm.create(typeIdentifier,arg,elData and elData.isElement)
  end
  local elData = registered_types[typeIdentifier]
  if(elData == nil or elData.isElement ~= shouldBeElement) then
    local expectedType = shouldBeElement and "element" or "attribute"
    local msg = "Attempted to create UDM " .. expectedType .. " of type " .. typeIdentifier
    if(elData ~= nil) then msg = msg .. " ('" .. elData.typeName .. "')" end
    console.print_warning(msg .. ", which is not a valid UDM " .. expectedType .. " type!")
    return
  end
  return elData.class(arg)
end

include("udm_attribute.lua")
include("udm_element.lua")

include("attributes")
include("elements")
