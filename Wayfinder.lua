-- Author      : Wyomarus
-- Create Date : 9/7/2024 5:11:21 PM

local addonName, addon = ...
_G[addonName] = addon

-- Addon namespaces
addon.API = addon.API or {
    ["$Info"] = "API functions for the Wayfinder addon."
}

addon.Dependencies = addon.Dependencies or {
    ["$Info"] = "Libraries and other dependencies used by the Wayfinder addon."
}

addon.private = addon.private or {
    ["$Info"] = "Private functions and data for the Wayfinder addon."
}

addon.Constants = addon.Constants or {
    ["$Info"] = "Constants used by the Wayfinder addon."
}

local _p = addon.private
local api = addon.API
local _C = addon.Constants

assert(LibStub, addonName .. " requires LibStub")

-- Global helper functions --

-- Binds a method to an object, creating a closure
-- to capture the object as the first argument
-- so it can be called as a function without the object reference as the first argument
-- (i.e. obj:method() instead of obj.method(obj)).
local function bind(obj, method)
    assert(type(obj) == "table", "Expected obj to be a table")
    assert(type(method) == "function", "Expected method to be a function")

    return function(...)
        return method(obj, ...)
    end
end

-- Print a table to the default chat frame
local function printTable(table)
    assert(type(table) == "table", "Expected table to be a table")

    for key, value in pairs(table) do
        print(format("%s:", key), value)
    end
end

do -- CompassBanner manages the frame and elements of the compass banner.
    -- Cache global references
    local deg, rad = math.deg, math.rad
    local abs = math.abs
    local GetPlayerFacing = GetPlayerFacing
    local CreateFrame = CreateFrame
    local UIParent = UIParent

    -- Constants
    local BANNER_WIDTH = 600
    local HALF_BANNER_WIDTH = BANNER_WIDTH / 2
    local BANNER_HEIGHT = 25
    local FOV = 135
    local HALF_FOV = FOV / 2

    _C.BANNER_WIDTH = BANNER_WIDTH
    _C.BANNER_HEIGHT = BANNER_HEIGHT
    _C.FOV = FOV

    local playerFacing

    local elements = {}

    --- Add an element to the compass banner.
    --- @param name string The name of the element to be displayed on the compass banner.
    --- @param angleFunction function A function that returns the angle of the element relative to the player.
    --- @param createBannerMarker function A function that creates the UI element for the element on the compass banner.
    --- @param isMarkerSticky boolean Whether the marker should be sticky or not.
    local function addElementToBanner(name, angleFunction, createBannerMarker, isMarkerSticky)
        assert(type(name) == "string", "Expected name to be a string")
        assert(type(angleFunction) == "function", "Expected angleFunction to be a function")
        assert(type(createBannerMarker) == "function", "Expected createBannerMarker to be a function")

        local uiElement = createBannerMarker(addon.CompassBannerFrame)
        local element = {
            name = name,
            angleFunction = angleFunction,
            uiElement = uiElement,
            isSticky = isMarkerSticky or false
        }

        table.insert(elements, element)
    end

    api.AddElementToBanner = addElementToBanner

    -- Create the frame for the compass banner
    local function buildCompassBannerFrame()
        local frame = CreateFrame("Frame", "WayfinderCompassBannerFrame", UIParent)
        frame:SetSize(BANNER_WIDTH, BANNER_HEIGHT)
        frame:SetPoint("TOP", 0, -10)

        -- Create a texture for the vertical line
        local line = frame:CreateTexture(nil, "BACKGROUND")
        line:SetColorTexture(1, 1, 1, 1)               -- White color, fully opaque
        line:SetSize(2, frame:GetHeight())             -- Width of 2 pixels, height same as the frame
        line:SetPoint("CENTER", frame, "CENTER", 0, 0) -- Centered vertically in the frame

        return frame
    end

    addon.CompassBannerFrame = addon.CompassBannerFrame or buildCompassBannerFrame()

    local function asDegrees(radians)
        local degrees = deg(radians)
        degrees = 360 - degrees            -- adjust for clockwise rotation
        return (degrees % 360 + 360) % 360 -- normalize to [0, 360)
    end

    local function asRadians(degrees)
        degrees = 360 - degrees -- adjust for counterclockwise rotation
        return rad(degrees)
    end

    local function getRelativeAngle(angle1, angle2)
        local relativeAngle = angle1 - angle2
        return (relativeAngle % 360 + 360) % 360
    end

    -- Normalize angle to [-180, 180)
    local function normalizeAngle180(angle)
        if not angle then return end

        angle = (angle % 360 + 360) % 360
        if angle > 180 then
            angle = angle - 360
        end

        return angle
    end

    --- Get the relative angle to a target angle from the player's facing direction.
    --- @param angle number The target angle.
    --- @param facing number|nil The player's facing direction.
    --- @return number|nil The relative angle to the target angle.
    local function getRelativeAngleTo(angle, facing)
        facing = facing or GetPlayerFacing()
        if not facing then return end
        facing = asDegrees(facing)
        local relativeAngle = facing - angle
        return normalizeAngle180(relativeAngle)
    end

    local function calculateBannerPosition(relativeAngle, isSticky, element)
        isSticky = isSticky or false
        relativeAngle = -relativeAngle -- reverse direction for UI
        if abs(relativeAngle) < HALF_FOV then
            if element.uiElement then
                element.uiElement:SetRotation(0)
            end
            return (relativeAngle / HALF_FOV) * HALF_BANNER_WIDTH
        elseif isSticky then
            -- Rotate the marker 90 degrees when out of the field of view
            if element.uiElement then
                element.uiElement:SetRotation(rad(relativeAngle < 0 and 90 or -90))
            end
            return relativeAngle < 0 and -HALF_BANNER_WIDTH or HALF_BANNER_WIDTH
        else
            return nil
        end
    end

    local function updateElementPosition(element, position)
        if element.uiElement:GetPoint() ~= position then
            element.uiElement:SetPoint("CENTER", addon.CompassBannerFrame, "CENTER", position, 0)
        end
        element.uiElement:Show()
    end

    local function processElement(element)
        if not element then return end

        playerFacing = GetPlayerFacing() -- could also check if player is in an instance
        if not playerFacing then return end

        local angle = element.angleFunction() -- this is the big call to avoid when possible
        local relativeAngle = angle and getRelativeAngleTo(angle, playerFacing)

        if not relativeAngle then
            element.uiElement:Hide()
            return
        end

        local position = calculateBannerPosition(relativeAngle, element.isSticky, element)
        if position then
            updateElementPosition(element, position)
        else
            element.uiElement:Hide()
        end
    end

    local function onUpdate(...)
        for _, element in ipairs(elements) do
            processElement(element)
        end
    end

    addon.CompassBannerFrame:SetScript("OnUpdate", onUpdate)
end

do -- CardinalPoints manages the cardinal points on the compass banner.
    local cardinalDirections = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

    local function calculateAngle(index, totalDirections)
        return (index - 1) * (360 / totalDirections)
    end

    local function createMarker(frame, direction)
        local fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fontString:SetText(direction)
        return fontString
    end

    for i = 1, #cardinalDirections do
        local direction = cardinalDirections[i]
        api.AddElementToBanner(
            direction,
            function()
                return calculateAngle(i, #cardinalDirections)
            end,
            function(frame)
                return createMarker(frame, direction)
            end,
            false
        )
    end
end

do -- SuperTracking manages the SuperTracking icon on the compass banner.
    local deg = math.deg
    local print = print
    local format = string.format

    local Enum = _G.Enum

    local Map = C_Map
    local GetUserWaypoint = Map.GetUserWaypoint
    local GetBestMapForUnit = Map.GetBestMapForUnit
    local GetWorldPosFromMapPos = Map.GetWorldPosFromMapPos
    local GetPlayerMapPosition = Map.GetPlayerMapPosition
    local GetMapInfo = Map.GetMapInfo
    local GetMapChildrenInfo = Map.GetMapChildrenInfo

    local QuestLog = C_QuestLog
    local GetLogIndexForQuestID = QuestLog.GetLogIndexForQuestID
    local QuestLogGetInfo = QuestLog.GetInfo
    local QuestLogIsOnMap = QuestLog.IsOnMap
    local QuestLogGetNextWaypoint = QuestLog.GetNextWaypoint

    local GetQuestPOIs = _G["GetQuestPOIs"]

    local QuestOffer = C_QuestOffer
    local QuestOfferGetMap = QuestOffer.GetMap

    local SuperTrack = C_SuperTrack
    local IsSuperTrackingAnything = SuperTrack.IsSuperTrackingAnything
    local GetHighestPrioritySuperTrackingType = SuperTrack.GetHighestPrioritySuperTrackingType
    local GetSuperTrackedQuestID = SuperTrack.GetSuperTrackedQuestID
    local GetSuperTrackedMapPin = SuperTrack.GetSuperTrackedMapPin

    local AreaPoiInfo = C_AreaPoiInfo
    local GetAreaPOIInfo = AreaPoiInfo.GetAreaPOIInfo

    local TaxiMap = C_TaxiMap
    local GetTaxiNodesForMap = TaxiMap.GetTaxiNodesForMap

    local hbd = LibStub("HereBeDragons-2.0")
    assert(hbd, "HereBeDragons-2.0 is required by the Wayfinder SuperTracking module")
    addon.Dependencies["HereBeDragons-2.0"] = hbd

    local GetPlayerWorldPosition = bind(hbd, hbd.GetPlayerWorldPosition)
    local GetPlayerZone = bind(hbd, hbd.GetPlayerZone)
    local GetPlayerZonePosition = bind(hbd, hbd.GetPlayerZonePosition)
    local GetUnitWorldPosition = bind(hbd, hbd.GetUnitWorldPosition)

    local GetWorldVector = bind(hbd, hbd.GetWorldVector)
    local GetWorldCoordinatesFromZone = bind(hbd, hbd.GetWorldCoordinatesFromZone)

    -- helper functions
    local function GetContinentIdFromMapId(uiMapId)
        local mapInfo = C_Map.GetMapInfo(uiMapId)
        if not mapInfo then return end
        local uiMapType = mapInfo.mapType
        if uiMapType == Enum.UIMapType.Continent then
            return uiMapId
        end
        local parent = mapInfo.parentMapID
        if parent then
            return GetContinentIdFromMapId(parent)
        end
    end

    -- Get all the maps in the game recursively as a tree structure
    local function getAllTheMaps(parentMapID)
        local function addMaps(mapID, maps)
            local mapInfo = GetMapInfo(mapID)
            if not mapInfo then return end
            local map = {}
            for key, value in pairs(mapInfo) do
                map[key] = value
            end
            maps[map.name] = map
            for _, childMap in ipairs(GetMapChildrenInfo(mapID)) do
                local childMapInfo = GetMapInfo(childMap.mapID)
                if childMapInfo then
                    addMaps(childMap.mapID, map)
                end
            end
        end

        local allMaps = {}
        local rootMapID = parentMapID or 946 -- map ID of Cosmic map
        addMaps(rootMapID, allMaps)
        return allMaps
    end

    local mapTree = getAllTheMaps()
    _p.MapTree = mapTree

    local function foo()
        local map = GetBestMapForUnit("player")
        if not map then return end
        local pos = GetPlayerMapPosition(map, "player")
        if not pos then return end
        local cid, wpos = GetWorldPosFromMapPos(map, pos)
        if not cid or not wpos then return end
        local x, y, i = GetPlayerWorldPosition()
        if not x or not y or not i then return end
        print("--------------------------------------------\n",
            "Map:", map,
            format("Pos: (%.4f, %.4f)\n", pos.x, pos.y),
            format("   World: (%.2f, %.2f)\n", wpos.x, wpos.y),
            format("  Player: (%.2f, %.2f) in %d", x, y, i))

        local function printMapInfo(map)
            local mapInfo = GetMapInfo(map)
            if not mapInfo then return end
            print(">>> Map info for map:", map)
            printTable(mapInfo)
            printMapInfo(mapInfo.parentMapID)
        end

        printMapInfo(map)
    end
    _p.Foo = foo

    -- local functions
    -- forward declarations
    local trackingFunctions

    --- Callback for the SuperTracking element on the compass banner.
    local function superTrackingCallback()
        if not IsSuperTrackingAnything() then return end

        local playerX, playerY, instanceId = GetPlayerWorldPosition()
        if not (playerX and playerY and instanceId) then return end

        local trackingType = GetHighestPrioritySuperTrackingType()
        if not trackingType then return end

        local trackingFunction = trackingFunctions[trackingType]
        if not trackingFunction then return end

        local destX, destY = trackingFunction()
        if not (destX and destY) then return end

        local angle, distance = GetWorldVector(instanceId, playerX, playerY, destX, destY)
        if not angle then return end

        return 360 - deg(angle)
    end

    local function functionNotImplemented() end

    local lastQuestInfo = nil
    local function superTrackingQuest()
        local questID = GetSuperTrackedQuestID()
        assert(questID, "Expected questID to be a number")

        local logIndex = GetLogIndexForQuestID(questID);
        if logIndex then
            local questInfo = QuestLogGetInfo(logIndex)

            if questInfo and questInfo ~= lastQuestInfo then
                print("--------------------------------------------")
                print("Quest info for questID:", questID)
                printTable(questInfo)
                lastQuestInfo = questInfo
            end
        end

        local mapID, x, y = QuestLogGetNextWaypoint(questID)
        if not mapID or not x or not y then return nil, nil end

        return GetWorldCoordinatesFromZone(x, y, mapID)
    end

    local function superTrackingUserWaypoint()
        local point = GetUserWaypoint()
        return GetWorldCoordinatesFromZone(point.position.x, point.position.y, point.uiMapID)
    end

    --- Get the world coordinates for the SuperTracking map pin.
    --- @return number|nil, number|nil The x and y coordinates of the map pin.
    local function superTrackingMapPin()
        local pinType, typeId = GetSuperTrackedMapPin()
        assert(pinType and typeId, "Expected pinType and typeId to be non-nil")

        local map = GetBestMapForUnit("player")
        if not map then return end

        local function handleAreaPOI()
            local info = GetAreaPOIInfo(map, typeId)
            assert(info, "Expected GetAreaPOIInfo to be non-nil")
            return info.position:GetXY()
        end

        local function handleQuestOffer()
        end

        local function handleTaxiNode()
            local nodes = GetTaxiNodesForMap(map)
            for _, node in ipairs(nodes) do
                if node.nodeID == typeId then
                    return GetWorldCoordinatesFromZone(node.position.x, node.position.y, map)
                end
            end
        end

        local function handleDigSite()
        end

        local mapPinTrackingFunctions = {
            [Enum.SuperTrackingMapPinType.AreaPOI] = handleAreaPOI,
            [Enum.SuperTrackingMapPinType.QuestOffer] = handleQuestOffer,
            [Enum.SuperTrackingMapPinType.TaxiNode] = handleTaxiNode,
            [Enum.SuperTrackingMapPinType.DigSite] = handleDigSite,
        }

        local mapPinTrackingFunction = mapPinTrackingFunctions[pinType]

        return mapPinTrackingFunction()
    end


    trackingFunctions = {
        [Enum.SuperTrackingType.Quest] = superTrackingQuest,
        [Enum.SuperTrackingType.UserWaypoint] = superTrackingUserWaypoint,
        [Enum.SuperTrackingType.Corpse] = functionNotImplemented,
        [Enum.SuperTrackingType.Scenario] = functionNotImplemented,
        [Enum.SuperTrackingType.Content] = functionNotImplemented,
        [Enum.SuperTrackingType.PartyMember] = functionNotImplemented,
        [Enum.SuperTrackingType.MapPin] = superTrackingMapPin,
        [Enum.SuperTrackingType.Vignette] = functionNotImplemented,
    }

    local SuperTrackedFrame = _G["SuperTrackedFrame"]
    local superTrackingIconTexture = nil

    local function getSuperTrackingIconTexture()
        if superTrackingIconTexture then return superTrackingIconTexture end
        local superTrackedIcon = SuperTrackedFrame and SuperTrackedFrame.Icon
        local texture = superTrackedIcon and superTrackedIcon:GetTexture()
        if texture then
            superTrackingIconTexture = texture
            return texture
        end
    end

    local superTrackingMarker = nil

    --- Create the SuperTracking marker for the compass banner
    local function createSuperTrackingMarker(frame)
        if superTrackingMarker then return superTrackingMarker end
        local superTrackedIconTexture = getSuperTrackingIconTexture()
        local marker = frame:CreateTexture(nil, "OVERLAY")
        marker:SetTexture(superTrackedIconTexture)
        marker:SetTexCoord(0.5, 1.0, 0.0, 0.5) -- should be the upper-right quadrant
        marker:SetSize(25, 25)
        superTrackingMarker = marker
        return marker
    end

    local isSticky = true

    api.AddElementToBanner(
        "SuperTracking",
        superTrackingCallback,
        createSuperTrackingMarker,
        isSticky
    )
end

do -- Slash commands
    local function ShowCompassBanner()
        addon.CompassBannerFrame:Show()
        print("Compass banner shown.")
    end

    local function HideCompassBanner()
        addon.CompassBannerFrame:Hide()
        print("Compass banner hidden.")
    end

    local function EnableCardinalPoints()
        addon.CardinalPoints:Show()
        print("CardinalPoints enabled.")
    end

    local function DisableCardinalPoints()
        addon.CardinalPoints:Hide()
        print("CardinalPoints disabled.")
    end

    local function EnableSuperTracking()
        addon.SuperTracking:Enable()
        print("SuperTracking enabled.")
    end

    local function DisableSuperTracking()
        addon.SuperTracking:Disable()
        print("SuperTracking disabled.")
    end

    local function PrintUsage()
        print("Usage:")
        print("/wayfinder show - Show the compass banner")
        print("/wayfinder hide - Hide the compass banner")
        print("/wayfinder compass enable|disable - Enable or disable the CardinalPoints")
        print("/wayfinder tracking enable|disable - Enable or disable SuperTracking")
    end

    local commandHandlers = {
        show = ShowCompassBanner,
        hide = HideCompassBanner,
        compass = {
            enable = EnableCardinalPoints,
            disable = DisableCardinalPoints,
        },
        tracking = {
            enable = EnableSuperTracking,
            disable = DisableSuperTracking,
        }
    }

    local function HandleSlashCommands(msg)
        local command, subcommand = msg:match("^(%S*)%s*(.-)$")
        local handler = commandHandlers[command]

        if type(handler) == "function" then
            handler()
        elseif type(handler) == "table" then
            local subHandler = handler[subcommand]
            if type(subHandler) == "function" then
                subHandler()
            else
                PrintUsage()
            end
        else
            PrintUsage()
        end
    end

    local SlashCmdList = _G["SlashCmdList"]
    -- Register the slash command
    SLASH_WAYFINDER1 = "/wayfinder"
    SLASH_WAYFINDER2 = "/wf"
    SlashCmdList["WAYFINDER"] = HandleSlashCommands
end
