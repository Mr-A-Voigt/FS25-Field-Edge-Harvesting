-- Field Edge Harvesting --
-- Aksel v --
-- November 2026 --
-- version: 1.0.0.0 --
--[[ status and functions this version
status:
first version of the mod

functions:
combine harvesters can now cut grass and meadow

]]--

-- original lua kode til FEH moddet --

RealisticHeaderEdge = {}

function RealisticHeaderEdge:loadMap(name)
    RealisticHeaderEdge.meadowFruitType = g_fruitTypeManager:getFruitTypeByName("MEADOW")
    RealisticHeaderEdge.grassFruitType = g_fruitTypeManager:getFruitTypeByName("GRASS")
end

function RealisticHeaderEdge:processCutterArea(superFunc, workArea, dt)
    -- 1. Kør skærebordets normale høst af korn først
    local realArea, area = superFunc(self, workArea, dt)

    -- 2. Tjek at skærebordet er tændt og sænket
    if self.getIsTurnedOn ~= nil and self.getIsLowered ~= nil then
        if self:getIsTurnedOn() and self:getIsLowered() then
            local xs, _, zs = getWorldTranslation(workArea.start)
            local xw, _, zw = getWorldTranslation(workArea.width)
            local xh, _, zh = getWorldTranslation(workArea.height)

            -- 3. Brug spillets egen græsklipper-funktion (FSDensityMapUtil.cutFruitArea)
            -- Parametre: (fruitTypeIndex, xs, zs, xw, zw, xh, zh, destroySpray, useMinGrowthState, minGrowthState, maxGrowthState, dropWindrow)
            if RealisticHeaderEdge.meadowFruitType ~= nil then
                FSDensityMapUtil.cutFruitArea(
                    RealisticHeaderEdge.meadowFruitType.index,
                    xs, zs, xw, zw, xh, zh,
                    true,  -- destroySpray
                    false, -- useMinGrowthState (klip uanset højde)
                    0, 0,
                    false  -- dropWindrow = false (efterlader IKKE græsskår på jorden)
                )
            end

            if RealisticHeaderEdge.grassFruitType ~= nil then
                FSDensityMapUtil.cutFruitArea(
                    RealisticHeaderEdge.grassFruitType.index,
                    xs, zs, xw, zw, xh, zh,
                    true,
                    false,
                    0, 0,
                    false
                )
            end
        end
    end

    return realArea, area
end

Cutter.processCutterArea = Utils.overwrittenFunction(Cutter.processCutterArea, RealisticHeaderEdge.processCutterArea)
addModEventListener(RealisticHeaderEdge)
