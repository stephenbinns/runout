local Render = {}

function Render.segment(width, lanes, x1, y1, w1, x2, y2, w2, color, fog) 
  local r1 = Render.rumbleWidth(w1, lanes)
  local r2 = Render.rumbleWidth(w2, lanes)
  local l1 = Render.laneMarkerWidth(w1, lanes)
  local l2 = Render.laneMarkerWidth(w2, lanes)
  local lanew1, lanew2, lanex1, lanex2

  love.graphics.setColor(Render.convertHex(color.grass))
  love.graphics.rectangle('fill', 0, y2, width, y1 - y2)

  Render.polygon(x1-w1-r1, y1, x1-w1, y1, x2-w2, y2, x2-w2-r2, y2, color.rumble)
  Render.polygon(x1+w1+r1, y1, x1+w1, y1, x2+w2, y2, x2+w2+r2, y2, color.rumble)
  Render.polygon(x1-w1,    y1, x1+w1, y1, x2+w2, y2, x2-w2,    y2, color.road)

  if (color.lane) then
    lanew1 = w1/lanes
    lanew2 = w2/lanes
    lanex1 = x1 - w1 + lanew1
    lanex2 = x2 - w2 + lanew2
    for _ = 1, lanes, 1 do
      lanex1 = lanex1 + lanew1
      lanex2 = lanex2 + lanew2
      Render.polygon(lanex1 - l1/2, y1, lanex1 + l1/2, y1, lanex2 + l2/2, y2, lanex2 - l2/2, y2, color.lane)
    end
  end

  Render.fog(0, y1, width, y2-y1, fog)
end

function Render.convertHex(hex)
  local splitToRGB = {}

  if # hex < 6 then hex = hex .. string.rep("F", 6 - # hex) end --flesh out bad hexes

  for x = 1, # hex - 1, 2 do
    table.insert(splitToRGB, tonumber(hex:sub(x, x + 1), 16)) --convert hexes to dec
    if splitToRGB[# splitToRGB] < 0 then splitToRGB[# splitToRGB] = 0 end --prevents negative values
  end

  return unpack(splitToRGB)
end

function Render.polygon(x1, y1, x2, y2, x3, y3, x4, y4, color) 
  love.graphics.setColor(Render.convertHex(color))
  love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
end

function Render.rumbleWidth(projectedRoadWidth, lanes)
  return projectedRoadWidth/math.max(6,  2*lanes)
end

function Render.laneMarkerWidth(projectedRoadWidth, lanes)
  return projectedRoadWidth/math.max(32, 8*lanes)
end

function Render.fog(x, y, width, height, fog)
  if fog < 1 then
    love.graphics.setColor(68, 40, 188, (1-fog) * 255)
    love.graphics.rectangle('fill', x, y, width, height)
    love.graphics.setColor(255,255,255,255)
  end
end

function Render.background(color)
  love.graphics.setColor(Render.convertHex(color))
  love.graphics.rectangle('fill', 0, 0, 640, 480)
end

function Render.sprite(width, height, resolution, roadWidth, sprites, sprite, scale, destX, destY, offsetX, offsetY, clipY)
  --  scale for projection AND relative to roadWidth (for tweakUI)
  SCALE = SCALE or 0.3 * (1/player:getWidth())

  local destW  = (sprite:getWidth() * scale * width/2) * (SCALE * (roadWidth/ 4))
  local destH  = (sprite:getHeight() * scale * height/2) * (SCALE * (roadWidth / 4))

  destX = destX + (destW * (offsetX or 0))
  destY = destY + (destH * (offsetY or 0))

  local clipH = 0
  if clipY then
    clipH = math.max(0, destY+destH-clipY) 
  else
    clipH = 0
  end

  if (clipH < destH) then
    love.graphics.draw(sprite, destX, destY, 0, scale * 1500)
  end

end

function Render.player(width, height, resolution, roadWidth, sprites, speedPercent, scale, destX, destY, steer, updown)

  local direction 
  if (2 * math.random()) > 1 then
    direction = 1
  else
    direction = -1
  end

  local bounce = (1.5 * math.random() * speedPercent * resolution) * direction
  local rotate

  if (steer < 0) then
    rotate = math.rad(-10)
  elseif (steer > 0) then
    rotate = math.rad(10)
  else
    rotate = math.rad(0)
  end

  xOffset = xOffset or player:getWidth() / 2
  yOffset = yOffset or player:getHeight()
  love.graphics.draw(player, destX - xOffset, destY + bounce - yOffset, rotate)
end

return Render