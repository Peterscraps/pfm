--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

udm.ELEMENT_TYPE_PFM_GRAPH_CURVE = udm.register_element("PFMGraphCurve")
udm.register_element_property(udm.ELEMENT_TYPE_PFM_GRAPH_CURVE,"keyTimes",udm.Array(udm.ATTRIBUTE_TYPE_FLOAT))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_GRAPH_CURVE,"keyValues",udm.Array(udm.ATTRIBUTE_TYPE_FLOAT))