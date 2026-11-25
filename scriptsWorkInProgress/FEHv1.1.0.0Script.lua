
-- Field Edge Harvesting --
-- version: 1.1.0.0 --
-- 24 November 2026 --
-- in development --
--[[
description:
this version is supposed to add straw effects when harvesting grass only
the plan is to use the effect from long grain rice as it looks like grass

status:
partially works
needs some refinement

feel free to suggest solutions or ideas

]]


RealisticHeaderEdge = {}

function RealisticHeaderEdge:loadMap(name)
    RealisticHeaderEdge.meadowFruitType = g_fruitTypeManager:getFruitTypeByName("MEADOW")
    RealisticHeaderEdge.grassFruitType = g_fruitTypeManager:getFruitTypeByName("GRASS")
    RealisticHeaderEdge.riceFruitType = g_fruitTypeManager:getFruitTypeByName("RICE")
end

function RealisticHeaderEdge:processCutterArea(superFunc, workArea, dt)
    -- 1. Kør først skærebordets normale høst af korn
    local realArea, area = superFunc(self, workArea, dt)
    local hasGrain = (realArea ~= nil and realArea > 0) or (area ~= nil and area > 0)

    local attacherVehicle = (self.getAttacherVehicle ~= nil) and self:getAttacherVehicle() or nil
    local now = g_currentMission.time

    -- 2. Hvis ANY workArea rammer korn: sæt en 300 ms spærre for græs-animationen,
    -- så yderkantens workArea ikke tænder ris-teksturen i samme frame!
    if hasGrain then
        self.realisticHeaderEdgeLastGrainTime = now + 300
        self.realisticHeaderEdgeGrassTime = nil

        if attacherVehicle ~= nil then
            attacherVehicle.realisticHeaderEdgeChopperTime = nil
            local combineSpec = attacherVehicle.spec_combine
            local cutterSpec = self.spec_cutter
            if combineSpec ~= nil and cutterSpec ~= nil and cutterSpec.currentInputFillType ~= nil then
                local chopperEffects = combineSpec.strawChopperEffects or combineSpec.chopperEffects
                if chopperEffects ~= nil then
                    g_effectManager:setEffectTypeInfo(chopperEffects, cutterSpec.currentInputFillType, cutterSpec.currentInputFruitType, nil)
                end
            end
        end
        return realArea, area
    end

    if self.getIsTurnedOn ~= nil and self.getIsLowered ~= nil then
        if self:getIsTurnedOn() and self:getIsLowered() then
            local xs, _, zs = getWorldTranslation(workArea.start)
            local xw, _, zw = getWorldTranslation(workArea.width)
            local xh, _, zh = getWorldTranslation(workArea.height)

            local cutGrassArea = 0

            if RealisticHeaderEdge.meadowFruitType ~= nil then
                local meadowArea = FSDensityMapUtil.cutFruitArea(
                    RealisticHeaderEdge.meadowFruitType.index,
                    xs, zs, xw, zw, xh, zh,
                    true, false, 0, 0, false
                )
                cutGrassArea = cutGrassArea + (meadowArea or 0)
            end

            if RealisticHeaderEdge.grassFruitType ~= nil then
                local grassArea = FSDensityMapUtil.cutFruitArea(
                    RealisticHeaderEdge.grassFruitType.index,
                    xs, zs, xw, zw, xh, zh,
                    true, false, 0, 0, false
                )
                cutGrassArea = cutGrassArea + (grassArea or 0)
            end

            -- 3. Klipningen af græsset sker altid (så kanten bliver klippet rent),
            -- men animationen tændes KUN hvis ingen del af skærebordet har høstet korn de sidste 300 ms.
            local recentlyHarvestedGrain = (self.realisticHeaderEdgeLastGrainTime ~= nil and self.realisticHeaderEdgeLastGrainTime > now)

            if cutGrassArea > 0 and not recentlyHarvestedGrain then
                self.realisticHeaderEdgeGrassTime = now + 200

                if attacherVehicle ~= nil and attacherVehicle.spec_combine ~= nil then
                    attacherVehicle.realisticHeaderEdgeChopperTime = now + 300
                end
            end
        end
    end

    return realArea, area
end

-- 4. Styr start og stop af skærebordets græs-effekt
function RealisticHeaderEdge:onCutterUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_cutter
    local rice = RealisticHeaderEdge.riceFruitType
    if spec == nil or rice == nil or spec.effects == nil then
        return
    end

    local now = g_currentMission.time
    local recentlyHarvestedGrain = (self.realisticHeaderEdgeLastGrainTime ~= nil and self.realisticHeaderEdgeLastGrainTime > now)

    if not recentlyHarvestedGrain and self.realisticHeaderEdgeGrassTime ~= nil and self.realisticHeaderEdgeGrassTime > now then
        spec.currentInputFruitType = rice.index
        spec.currentInputFillType = FillType.RICE
        spec.lastValidInputFruitType = rice.index
        spec.lastValidInputFillType = FillType.RICE

        g_effectManager:setEffectTypeInfo(spec.effects, FillType.RICE, rice.index, nil)
        g_effectManager:startEffects(spec.effects)
        self.realisticHeaderEdgeCutterActive = true
    elseif self.realisticHeaderEdgeCutterActive then
        g_effectManager:stopEffects(spec.effects)
        self.realisticHeaderEdgeCutterActive = false
        self.realisticHeaderEdgeGrassTime = nil
    end
end

-- 5. Styr start og stop af mejetærskerens snitter-effekt
function RealisticHeaderEdge:onCombineUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_combine
    local rice = RealisticHeaderEdge.riceFruitType
    if spec == nil or rice == nil then
        return
    end

    local chopperEffects = spec.strawChopperEffects or spec.chopperEffects
    if chopperEffects == nil then
        return
    end

    local now = g_currentMission.time
    if self.realisticHeaderEdgeChopperTime ~= nil and self.realisticHeaderEdgeChopperTime > now and self:getIsTurnedOn() and spec.isSwathActive == false then
        g_effectManager:setEffectTypeInfo(chopperEffects, FillType.RICE, rice.index, nil)
        g_effectManager:startEffects(chopperEffects)
        self.realisticHeaderEdgeChopperActive = true
    elseif self.realisticHeaderEdgeChopperActive then
        g_effectManager:stopEffects(chopperEffects)
        self.realisticHeaderEdgeChopperActive = false
        self.realisticHeaderEdgeChopperTime = nil
    end
end

Cutter.processCutterArea = Utils.overwrittenFunction(Cutter.processCutterArea, RealisticHeaderEdge.processCutterArea)
Cutter.onUpdateTick = Utils.appendedFunction(Cutter.onUpdateTick, RealisticHeaderEdge.onCutterUpdateTick)
if Combine ~= nil and Combine.onUpdateTick ~= nil then
    Combine.onUpdateTick = Utils.appendedFunction(Combine.onUpdateTick, RealisticHeaderEdge.onCombineUpdateTick)
end
addModEventListener(RealisticHeaderEdge)