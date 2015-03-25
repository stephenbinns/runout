local Road = {}
local Util = require 'utils'
local Color = require 'color'

local LENGTH = { NONE =  0, SHORT =   25, MEDIUM =  50, LONG =  100 }
local HILL   = { NONE =  0, LOW   =   20, MEDIUM =  40, HIGH =   60 }
local CURVE =  { NONE =  0, EASY  =    2, MEDIUM =   4, HARD =    6 }

function addSegment(curve, y)
  --maybe need to offset 1 here.
  local n = table.getn(segments)
  local seg_color
  if math.floor(n / rumbleLength) % 2 == 0 then
    seg_color = Color.Dark()
  else
    seg_color = Color.Light()
  end

  table.insert(segments, {
      index = n,
      p1 = { world = { y= lastY(), z =  n   *segmentLength }, camera = {}, screen = {} },
      p2 = { world = { y= y,       z = (n+1)*segmentLength }, camera = {}, screen = {} },
      curve = curve,
      cars = {},
      sprites = {},
      color = seg_color
    })
end	

function addStraight(num) 
  num = num or LENGTH.MEDIUM
  addRoad(num, num, num, 0,  0)
end

function addHill(num, height) 
  num    = num    or LENGTH.MEDIUM
  height = height or HILL.MEDIUM
  addRoad(num, num, num, 0, height)
end

function addLowRollingHills(num, height)
  num    = num    or LENGTH.SHORT
  height = height or HILL.LOW
  addRoad(num, num, num,  0,  height/2)
  addRoad(num, num, num,  0, -height)
  addRoad(num, num, num,  0,  height)
  addRoad(num, num, num,  0,  0)
  addRoad(num, num, num,  0,  height/2)
  addRoad(num, num, num,  0,  0)
end

function addDownhillToEnd(num)
  num = num or 200
  addRoad(num, num, num, -CURVE.EASY, -lastY()/segmentLength)
end

function addCurve(num, curve, height) 
  num    = num    or LENGTH.MEDIUM
  curve  = curve  or CURVE.MEDIUM
  height = height or HILL.NONE
  addRoad(num, num, num, curve, height)
end

function addSCurves() 
  addRoad(LENGTH.MEDIUM, LENGTH.MEDIUM, LENGTH.MEDIUM,  -CURVE.EASY,    HILL.NONE)
  addRoad(LENGTH.MEDIUM, LENGTH.MEDIUM, LENGTH.MEDIUM,   CURVE.MEDIUM,  HILL.MEDIUM)
  addRoad(LENGTH.MEDIUM, LENGTH.MEDIUM, LENGTH.MEDIUM,   CURVE.EASY,   -HILL.LOW)
  addRoad(LENGTH.MEDIUM, LENGTH.MEDIUM, LENGTH.MEDIUM,  -CURVE.EASY,    HILL.MEDIUM)
  addRoad(LENGTH.MEDIUM, LENGTH.MEDIUM, LENGTH.MEDIUM,  -CURVE.MEDIUM, -HILL.MEDIUM)
end

function addBumps()
  addRoad(10, 10, 10, 0,  5);
  addRoad(10, 10, 10, 0, -2);
  addRoad(10, 10, 10, 0, -5);
  addRoad(10, 10, 10, 0,  8);
  addRoad(10, 10, 10, 0,  5);
  addRoad(10, 10, 10, 0, -7);
  addRoad(10, 10, 10, 0,  5);
  addRoad(10, 10, 10, 0, -2);
end

function lastY()
  local length = table.getn(segments)
  if length == 0 then
    return 0
  else
    local s = segments[length]
    return s.p2.world.y
  end
end

function addRoad(enter, hold, leave, curve, y)
  local startY = lastY()
  local endY = startY + (Util.toInt(y, 0) * segmentLength)
  local total = enter + hold + leave

  for n = 0, enter, 1 do
    addSegment(Util.easeIn(0, curve, n/enter), Util.easeInOut(startY, endY, n/total))
  end
  for n = 0, hold, 1 do
    addSegment(curve, Util.easeInOut(startY, endY, (enter+n)/total))
  end
  for n = 0, leave, 1 do 
    addSegment(Util.easeInOut(curve, 0, n/leave), Util.easeInOut(startY, endY, (enter+hold+n)/total))
  end
end

function addSprite(n, sprite, offset)
  segment = segments[n]
  table.insert(segment.sprites, { source = sprite, offset = offset })
end

function resetSprites()
  local n
  local segLen = table.getn(segments)

  for n = 1, segLen/ 20, 1 do
    local choice = math.random()

    if choice >= 0.6 and choice < 0.8 then
      addSprite(n * 20,  billboard, -1)
      addSprite(n * 20,  billboard, 1)
    elseif choice >= 0.8 and choice < 0.9 then
      addSprite(n * 20,  billboard, -1)
    elseif choice >= 0.9 then
      addSprite(n * 20,  billboard, 1)
    end
  end
end

function Road.reset()
  segments = {}

  addStraight(LENGTH.SHORT/2)
  addHill(LENGTH.SHORT, HILL.LOW)
  addLowRollingHills()
  addCurve(LENGTH.MEDIUM, CURVE.MEDIUM, HILL.LOW)
  addLowRollingHills()
  addCurve(LENGTH.LONG, CURVE.MEDIUM, HILL.MEDIUM)
  addStraight()
  addCurve(LENGTH.LONG, -CURVE.MEDIUM, HILL.MEDIUM)
  addHill(LENGTH.LONG, HILL.HIGH)
  addCurve(LENGTH.LONG, CURVE.MEDIUM, -HILL.LOW)
  addHill(LENGTH.LONG, -HILL.MEDIUM)
  addStraight()
  addDownhillToEnd()

  segments[findSegment(playerZ).index + 1].color.road = Color.Start()
  segments[findSegment(playerZ).index + 2].color.road = Color.Start()

  local length = table.getn(segments) 
  for n = 0,rumbleLength, 1 do
    segments[length-n].color.road = Color.Finish()
  end

  trackLength = length * segmentLength
  resetSprites()
end

return Road