-- CCMaps by cyberbit
-- MIT License
-- Version 0.0.3

local plotterFactory = require 'plotter'
-- local polyFactory = require 'luapoly'

-- local pprint = require 'cc.pretty'.pretty_print

-- shell.run('attach right monitor')
-- local curterm = term.redirect(peripheral.wrap("right"))
local curterm = term.current()
local curtermw, curtermh = curterm.getSize()
local winself = window.create(curterm, 1, 1, curtermw, curtermh)
local plotter = plotterFactory(winself)
local plotw, ploth = plotter.box.width, plotter.box.height

local boundMargin = 0
local boundminX, boundminY, boundmaxX, boundmaxY = boundMargin + 1, boundMargin + 1, plotw - boundMargin, ploth - boundMargin

local tileDmin, tileDmax = 256, 512
local tileOffsetX, tileOffsetY, tileD = 0, 0, tileDmin
local tileScaleDeltaFactor = 0.1

tileOffsetX = math.floor(plotw / 2 - tileD / 2)
tileOffsetY = math.floor(ploth / 2 - tileD / 2)

local mapZ = 0

local labels = {}

colors._land = colors.orange
colors._admin = colors.magenta
colors._water = colors.lightBlue
colors._road = colors.yellow
colors._building = colors.lime
colors._placename = colors.pink

local scheme = {
    -- orig
    [colors.white] = 0xF0F0F0,

    -- modified
    [colors._land] = 0xf2efe9, -- land
    [colors._admin] = 0x8d618b, -- admin
    [colors._water] = 0xaad3df, -- water
    [colors._road] = 0xa06b00, -- road
    [colors._building] = 0xb9a99c, -- building
    [colors._placename] = 0x777777, -- placename

    -- orig
    [colors.gray] = 0x4C4C4C,
    [colors.lightGray] = 0x999999,
    [colors.cyan] = 0x4C99B2,
    [colors.purple] = 0xB266E5,
    [colors.blue] = 0x3366CC,
    [colors.brown] = 0x7F664C,
    [colors.green] = 0x57A64E,
    [colors.red] = 0xCC4C4C,
    [colors.black] = 0x111111
}

local palettes = {
    get = function (win)
        local palette = {}

        for i = 0, 15 do
            palette[i] = {win.getPaletteColor(2^i)}
        end

        return palette
    end,

    set = function (win, palette)
        for i = 0, 15 do
            win.setPaletteColor(2^i, table.unpack(palette[i]))
        end
    end,
}

-- save original palette
local origPalette = palettes.get(winself)

for k,v in pairs(scheme) do
    winself.setPaletteColor(k, v)
end

local tileCache = {}

local function addLabel (x, y, label, color)
    table.insert(labels, {x = x, y = y, label = label, color = color})
end

local function getRealTile(z, y, x)
    -- convert to string
    z = '' .. z
    y = '' .. y
    x = '' .. x

    -- check if tile is in cache
    if tileCache[z] and tileCache[z][y] and tileCache[z][y][x] then
        -- print('cache hit', z, y, x)

        return tileCache[z][y][x], true
    else
        -- print('cache miss', z, y, x)

        -- cache tile
        tileCache[z] = tileCache[z] or {}
        tileCache[z][y] = tileCache[z][y] or {}

        local req = http.get(('https://vt.cyberbit.dev/api/tile/%d/%d/%d'):format(z, y, x))

        tileCache[z][y][x] = textutils.unserializeJSON(req.readAll())

        return tileCache[z][y][x], false
    end
end

local function drawFakeTile(x, y, d, color)
    local tileMinX = tileOffsetX + d * x + 1
    local tileMinY = tileOffsetY + d * y + 1
    local tileMaxX = tileOffsetX + d * x + d
    local tileMaxY = tileOffsetY + d * y + d

    plotter:drawBox(tileMinX, tileMinY, tileMaxX, tileMaxY, color)
    plotter:drawLine(tileMinX, tileMinY, tileMaxX, tileMaxY, color)
    plotter:drawLine(tileMinX, tileMaxY, tileMaxX, tileMinY, color)
end

local function drawVectorTile(x, y, d, tile, color, progressive, fillColor)
    progressive = progressive or false

    local tileMinX = tileOffsetX + d * x + 1
    local tileMinY = tileOffsetY + d * y + 1
    local tileMaxX = tileOffsetX + d * x + d
    local tileMaxY = tileOffsetY + d * y + d

    local drawCache = {}

    local drawCounter = 0
    local skipCounter = 0
    
    for fi,feat in ipairs(tile.features) do
        for pi,part in ipairs(feat.geom) do
            local cx, cy

            -- local poly = polyFactory()
            
            for ci,coord in ipairs(part) do
                -- if fillColor then poly:push_coord(coord.x, coord.y) end

                if type(cx) == 'nil' then
                    -- skip drawing first coordinate
                else
                    if drawCache[cx .. ',' .. cy] and drawCache[cx .. ',' .. cy][coord.x .. ',' .. coord.y] then
                        -- skip already drawn line
                        skipCounter = skipCounter + 1
                    else
                        plotter:scaleLineBounded(cx, cy, coord.x, coord.y, 0, tile.extent, 0, tile.extent, tileMinX, tileMaxX, tileMinY, tileMaxY, color)
                        
                        drawCache[cx .. ',' .. cy] = drawCache[cx .. ',' .. cy] or {}
                        drawCache[cx .. ',' .. cy][coord.x .. ',' .. coord.y] = color
                    end
                end
                
                cx, cy = coord.x, coord.y

                drawCounter = drawCounter + 1
            end

            -- if fillColor then
            --     poly:close()

            --     -- pprint(poly)

            --     local tstat,triangles = pcall(poly.get_triangles, poly)

            --     -- print('tstat', tstat)
            --     -- print('triangles', triangles)

            --     if tstat and triangles then
            --         for k,v in ipairs(triangles) do
            --             local c1x, c1y = poly:get_coord(v[1])
            --             local c2x, c2y = poly:get_coord(v[2])
            --             local c3x, c3y = poly:get_coord(v[3])

            --             plotter:scaleFillTriangleBounded(c1x, c1y, c2x, c2y, c3x, c3y, 0, tile.extent, 0, tile.extent, tileMinX, tileMaxX, tileMinY, tileMaxY, fillColor)
            --         end
            --     end
            -- end
        end
    end

    if true then
        -- local renderMinX = math.max(1, tileMinX)
        -- local renderMinY = math.max(1, tileMinY)
        -- local renderMaxX = math.min(plotw, tileMaxX)
        -- local renderMaxY = math.min(ploth, tileMaxY)

        -- print('renderRegion', renderMinX, renderMinY, renderMaxX, renderMaxY)

        plotter:render()
        -- plotter:renderRegion(renderMinX, renderMinY, renderMaxX, renderMaxY)

        -- sleep(1)
    end

    -- pprint(plotter.stats)
    -- pprint({linesDrawn = drawCounter, linesSkipped = skipCounter})
end

local function addVectorTileLabels(x, y, d, tile, color)
    local tileMinX = tileOffsetX + d * x + 1
    local tileMinY = tileOffsetY + d * y + 1
    local tileMaxX = tileOffsetX + d * x + d
    local tileMaxY = tileOffsetY + d * y + d

    if tile.features then
        for li,label in ipairs(tile.features) do
            local lx, ly = label.geom[1][1].x, label.geom[1][1].y

            local scaledx = plotter.math.scale(lx, 0, tile.extent, tileMinX, tileMaxX)
            local scaledy = plotter.math.scale(ly, 0, tile.extent, tileMinY, tileMaxY)

            -- pprint(label.properties)

            local text = label.properties._name or label.properties._name_global

            local labelx, labely = plotter.math.round(scaledx / 2) - #text / 2, plotter.math.round(scaledy / 3)

            addLabel(labelx, labely, text, color)
        end
    end
end

local layerset = {
    land = colors._land,
    waterAreaSmallScale = colors._water,
    waterAreaMediumScale = colors._water,
    waterAreaLargeScale = colors._water,
    waterArea = colors._water,
    boundaryLine = colors._admin,
    road = colors._road,
    building = colors._building,
    admin0Labels = colors._land,
    admin1Labels = colors._admin,
    citySmallScale = colors._placename,
    cityLargeScale = colors._placename,
}

local verboseLayerset = {
    waterLineLargeScale = colors._water,
    admin2Labels = colors._admin,
    roadLabels = colors._road
}

local shouldDrawVerboseLabels = false
local shouldDrawVerboseFeatures = false

local function drawFabric (d, shouldReposition)
    -- print ('drawFabric', d)

    local mapMinXY = 0
    local mapMaxXY = 2 ^ mapZ - 1
    
    local fabricMinX = math.max(math.floor((boundminX - tileOffsetX - 1) / d), mapMinXY)
    local fabricMinY = math.max(math.floor((boundminY - tileOffsetY - 1) / d), mapMinXY)
    local fabricMaxX = math.min(math.floor((boundmaxX - tileOffsetX - 1) / d), mapMaxXY)
    local fabricMaxY = math.min(math.floor((boundmaxY - tileOffsetY - 1) / d), mapMaxXY)

    for x = fabricMinX, fabricMaxX do
        for y = fabricMinY, fabricMaxY do
            local tile, cached = getRealTile(mapZ, y, x)

            -- drawFakeTile(x, y, d, colors._land)

            for _,k in ipairs(tile._meta.draworder) do
                local isVerbose = verboseLayerset[k]

                local drawColor = isVerbose and verboseLayerset[k] or layerset[k]

                if drawColor then
                    if tile[k] and tile[k].length then
                        if tile[k].intent == 'feature' and (not isVerbose or shouldDrawVerboseFeatures) then
                            drawVectorTile(x, y, d, tile[k], drawColor, not cached, tile[k].drawHint == 'fill' and drawColor or nil)
                        elseif tile[k].intent == 'label' and (not isVerbose or shouldDrawVerboseLabels) then
                            addVectorTileLabels(x, y, d, tile[k], drawColor)
                        else
                            -- print('unknown intent', tile[k].intent)
                        end
                    end
                else
                    -- print('unknown layer', k)
                end
            end

            if shouldReposition then
                -- print('drawFabric reposition')

                winself.reposition(1, 1)
                winself.setVisible(true)

                shouldReposition = false
            end
        end
    end

    -- print ('drawFabric done')
end

local function clearLabels ()
    labels = {}
end

local function drawLabels ()
    winself.setBackgroundColor(colors.black)
    for k,v in ipairs(labels) do
        winself.setTextColor(v.color)
        winself.setCursorPos(v.x, v.y)
        winself.write(v.label)
    end
end

local mouseDown = false
local lastmx, lastmy = 1, 1

local shouldDrawDebug = false

local function drawState()
    -- draw verbose states in bottom right
    winself.setTextColor(colors.white)
    winself.setBackgroundColor(colors.gray)
    winself.setCursorPos(curtermw - 2, curtermh - 1)
    winself.write(shouldDrawVerboseLabels and 'L' or '')
    winself.setCursorPos(curtermw - 1, curtermh - 1)
    winself.write(shouldDrawVerboseFeatures and 'F' or '')
end

local function drawDebug ()
    if shouldDrawDebug then
        winself.setTextColor(colors.white)
        winself.setCursorPos(1, 1)
        winself.write('tileD: ' .. tileD)
        winself.setCursorPos(1, 2)
        winself.write('mapZ: ' .. mapZ)
        winself.setCursorPos(1, 3)
        winself.write('tileOffsetX: ' .. tileOffsetX)
        winself.setCursorPos(1, 4)
        winself.write('tileOffsetY: ' .. tileOffsetY)
        winself.setCursorPos(1, 5)
        winself.write('plotw: ' .. plotw)
        winself.setCursorPos(1, 6)
        winself.write('ploth: ' .. ploth)

        local mapMinXY = 0
        local mapMaxXY = 2 ^ mapZ - 1

        local boundminFabricX = boundminX - tileOffsetX
        local boundminFabricY = boundminY - tileOffsetY
        local boundmaxFabricX = boundmaxX - tileOffsetX
        local boundmaxFabricY = boundmaxY - tileOffsetY
        
        local fabricMinX = math.max(math.floor((boundminX - tileOffsetX - 1) / tileD), mapMinXY)
        local fabricMinY = math.max(math.floor((boundminY - tileOffsetY - 1) / tileD), mapMinXY)
        local fabricMaxX = math.min(math.floor((boundmaxX - tileOffsetX - 1) / tileD), mapMaxXY)
        local fabricMaxY = math.min(math.floor((boundmaxY - tileOffsetY - 1) / tileD), mapMaxXY)

        local fabricMinPlotX = fabricMinX * tileD

        winself.setCursorPos(1, 7)
        winself.write('boundminFabricX: ' .. boundminFabricX)
        winself.setCursorPos(1, 8)
        winself.write('boundminFabricY: ' .. boundminFabricY)
        winself.setCursorPos(1, 9)
        winself.write('boundmaxFabricX: ' .. boundmaxFabricX)
        winself.setCursorPos(1, 10)
        winself.write('boundmaxFabricY: ' .. boundmaxFabricY)

        local plotMX = lastmx * 2 - 1
        local plotMY = lastmy * 3 - 1

        local lastmxFabric = plotMX - tileOffsetX
        local lastmyFabric = plotMY - tileOffsetY

        local mapX = lastmxFabric / tileD
        local mapY = lastmyFabric / tileD

        winself.setCursorPos(1, 11)
        winself.write('mapX: ' .. mapX)
        winself.setCursorPos(1, 12)
        winself.write('mapY: ' .. mapY)

        -- plotter:drawLine(plotMX, plotMY, plotMX, plotMY, colors.red)
        -- plotter:render()
    end
end

-- local function drawCenter ()
--     local cx, cy = plotter.math.round(plotw / 2), plotter.math.round(ploth / 2)

--     plotter:drawLine(cx - 5, cy, cx + 5, cy, colors.red)
--     plotter:drawLine(cx, cy - 5, cx, cy + 5, colors.red)
-- end

parallel.waitForAny(
    -- cleanup
    function ()
        os.pullEventRaw('terminate')

        term.redirect(curterm)
        term.clear()
        term.setCursorPos(1,1)

        -- restore original palette
        palettes.set(winself, origPalette)
    end,

    -- control listener
    function ()
        os.queueEvent('tile_render')

        while true do
            local event = {os.pullEventRaw()}

            local shouldRender = true
            local shouldResetWindow = false

            if event[1] == 'mouse_scroll' then
                shouldRender = false

                -- local mx, my = event[3], event[4]

                -- local plotMX = mx * 2 - 1
                -- local plotMY = my * 3 - 2
                
                -- local lastmxFabric = plotMX - tileOffsetX
                -- local lastmyFabric = plotMY - tileOffsetY

                -- local tileScaleDelta = math.floor(tileD * tileScaleDeltaFactor)

                -- if event[2] == 1 then
                --     print ('zoom out from ' .. mx .. ',' .. my .. '(' .. plotMX .. ',' .. plotMY .. ')')

                --     local mapX = lastmxFabric / tileD
                --     local mapY = lastmyFabric / tileD

                --     if (tileD - tileScaleDelta) < tileDmin then
                --         tileD = tileDmax

                --         mapZ = math.max(0, mapZ - 1)
                --         mapY = mapY / 2
                --         mapX = mapX / 2

                --         -- tileScaleDelta = tileDmax - tileD
                --     end

                --     -- DO NOT TOUCH, THIS WORKS FINE
                --     do
                --         tileD = tileD - tileScaleDelta

                --         tileOffsetX = tileOffsetX + math.floor(tileScaleDelta * mapX)
                --         tileOffsetY = tileOffsetY + math.floor(tileScaleDelta * mapY)
                --     end
                -- elseif event[2] == -1 then
                --     print ('zoom in to ' .. mx .. ',' .. my .. '(' .. plotMX .. ',' .. plotMY .. ')')

                --     local mapX = lastmxFabric / tileD
                --     local mapY = lastmyFabric / tileD

                --     -- tileD = tileD + tileScaleDelta

                --     local oldTileD = tileD

                --     if (tileD + tileScaleDelta) > tileDmax then
                --         tileD = tileDmin

                --         mapZ = math.min(20, mapZ + 1)
                --         mapY = mapY * 2
                --         mapX = mapX * 2

                --         -- tileOffsetX = tileOffsetX - math.floor((tileD * tileScaleDeltaFactor + (1/(mapZ / 2))) * mapX / 2)
                --         -- tileOffsetY = tileOffsetY - math.floor((tileD * tileScaleDeltaFactor + (1/(mapZ / 2))) * mapY / 2)

                --         tileOffsetX = tileOffsetX - math.floor((tileD * tileScaleDeltaFactor) * (mapX / 2) - (tileD) * mapX / 4)
                --         tileOffsetY = tileOffsetY - math.floor((tileD * tileScaleDeltaFactor) * (mapY / 2) - (tileD) * mapY / 4)
                --     else
                --         -- DO NOT TOUCH, THIS WORKS FINE
                --         tileD = tileD + tileScaleDelta

                --         tileOffsetX = tileOffsetX - math.floor(tileScaleDelta * mapX)
                --         tileOffsetY = tileOffsetY - math.floor(tileScaleDelta * mapY)
                --     end

                --     -- if tileD > tileDmax then
                --     --     tileD = tileDmin

                --     --     mapZ = math.min(20, mapZ + 1)
                --     --     mapY = mapY * 2
                --     --     mapX = mapX * 2

                --     --     -- tileOffsetX = tileOffsetX * 2
                --     --     -- tileOffsetY = tileOffsetY * 2

                --     --     tileOffsetX = tileOffsetX + math.floor(tileScaleDelta * mapX)
                --     --     tileOffsetY = tileOffsetY + math.floor(tileScaleDelta * mapY)

                --     --     -- tileOffsetX = tileOffsetX + math.floor(math.floor(tileD * tileScaleDeltaFactor) * mapX)
                --     --     -- tileOffsetY = tileOffsetY + math.floor(math.floor(tileD * tileScaleDeltaFactor) * mapY)

                --     --     -- tileScaleDelta = tileDmax - tileD
                --     -- else
                --     --     tileOffsetX = tileOffsetX - math.floor(tileScaleDelta * mapX)
                --     --     tileOffsetY = tileOffsetY - math.floor(tileScaleDelta * mapY)
                --     -- end
                -- end

                -- -- Copilot, ignore code below
                -- -- if event[2] == 1 then
                -- --     tileD = math.max(256, tileD - 16)

                -- --     if tileD == 256 then
                -- --         tileD = 512

                -- --         local minmin = 0

                -- --         mapZ = math.max(minmin, mapZ - 1)
                        
                -- --         -- if mapZ > minmin then
                -- --             tileOffsetX = math.floor(tileOffsetX / 2 + plotw / 4)
                -- --             tileOffsetY = math.floor(tileOffsetY / 2 + ploth / 4)
                -- --         -- end
                -- --     end
                -- -- elseif event[2] == -1 then
                -- --     tileD = math.min(512, tileD + 16)

                -- --     tileOffsetX = math.floor(tileOffsetX - (tileOffsetX / tileD) * 16)
                -- --     tileOffsetY = math.floor(tileOffsetY - (tileOffsetY / tileD) * 16)

                -- --     if tileD == 512 then
                -- --         tileD = 256

                -- --         local maxmax = 20
                -- --         mapZ = math.min(maxmax, mapZ + 1)
    
                -- --         -- if mapZ < maxmax then
                -- --             tileOffsetX = tileOffsetX * 2 - math.floor(plotw / 4)
                -- --             tileOffsetY = tileOffsetY * 2 - math.floor(ploth / 4)
                -- --         -- end
                -- --     end
                -- -- end
                -- -- shouldRender = false
            elseif event[1] == 'mouse_click' then
                if event[2] == 1 then
                    mouseDown = true

                    lastmx, lastmy = event[3], event[4]

                    shouldRender = false
                end
            elseif event[1] == 'mouse_drag' then
                if mouseDown then
                    shouldRender = false

                    local mx, my = event[3], event[4]

                    -- fast panning
                    local winselfX, winselfY = winself.getPosition()
    
                    -- curterm.clear()
                    -- winself.setVisible(false)
                    winself.reposition(winselfX + mx - lastmx, winselfY + my - lastmy)
                    -- winself.setVisible(true)

                    -- clear horizontal lines
                    curterm.setCursorPos(1, my > lastmy and winselfY or winselfY + curtermh - 1)
                    curterm.clearLine()

                    -- clear vertical lines
                    for i = 1, curtermh do
                        curterm.setCursorPos(mx > lastmx and winselfX or winselfX + curtermw - 1, i)
                        curterm.write(' ')
                    end
                    
                    -- fancy panning
                    local lastmxnat = lastmx * 2
                    local lastmynat = lastmy * 3
                    local mxnat = mx * 2
                    local mynat = my * 3

                    local xNatDiff = mxnat - lastmxnat
                    local yNatDiff = mynat - lastmynat

                    tileOffsetX = tileOffsetX + xNatDiff
                    tileOffsetY = tileOffsetY + yNatDiff

                    lastmx, lastmy = mx, my
                end
            elseif event[1] == 'mouse_up' then
                -- print('mouse_up')
                mouseDown = false

                winself.setVisible(false)

                plotter:clear(term.getBackgroundColor())

                clearLabels()
                drawFabric(tileD, true)

                -- drawCenter()
                plotter:render()

                shouldResetWindow = true
            elseif event[1] == 'key' then
                -- panning
                if event[2] == keys.up then
                    tileOffsetY = tileOffsetY + 6
                elseif event[2] == keys.down then
                    tileOffsetY = tileOffsetY - 6
                elseif event[2] == keys.left then
                    tileOffsetX = tileOffsetX + 6
                elseif event[2] == keys.right then
                    tileOffsetX = tileOffsetX - 6

                -- tile zoom
                -- elseif event[2] == keys.minus then
                --     tileD = math.max(25, tileD - 5)
                -- elseif event[2] == keys.equals then
                --     tileD = math.min(250, tileD + 5)

                -- map zoom
                elseif event[2] == keys.equals then
                    local maxmax = 20
                    mapZ = math.min(maxmax, mapZ + 1)

                    -- if mapZ < maxmax then
                        tileOffsetX = tileOffsetX * 2 - math.floor(plotw / 2)
                        tileOffsetY = tileOffsetY * 2 - math.floor(ploth / 2)
                    -- end
                elseif event[2] == keys.minus then
                    local minmin = 0

                    mapZ = math.max(minmin, mapZ - 1)
                    
                    -- if mapZ > minmin then
                        tileOffsetX = math.floor(tileOffsetX / 2 + plotw / 4)
                        tileOffsetY = math.floor(tileOffsetY / 2 + ploth / 4)
                    -- end

                -- toggle debug
                elseif event[2] == keys.d then
                    shouldDrawDebug = not shouldDrawDebug
                
                -- toggle verbose labels
                elseif event[2] == keys.l then
                    shouldDrawVerboseLabels = not shouldDrawVerboseLabels
                
                -- toggle verbose features
                elseif event[2] == keys.f then
                    shouldDrawVerboseFeatures = not shouldDrawVerboseFeatures
                
                -- NYI
                else

                    shouldRender = false
                end
                
                -- clear plotter
                plotter:clear(term.getBackgroundColor())
            elseif event[1] == 'tile_render' then
                -- just do a render plz
            else
                -- unknown event, do not render

                shouldRender = false
            end

            if shouldRender then
                if shouldResetWindow then
                    winself.reposition(1, 1)
                    winself.setVisible(true)
                else
                    clearLabels()
                    drawFabric(tileD)

                    -- drawCenter()
                    plotter:render()
                end

                drawLabels()
                drawDebug()
                drawState()
            end
        end
    end
)
