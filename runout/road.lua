local Road = {}
local Util = require 'utils'
local Color = require 'color'

local ROAD = {
  LENGTH = { NONE =  0, SHORT =   25, MEDIUM =  50, LONG =  100 },
  HILL   = { NONE =  0, LOW   =   20, MEDIUM =  40, HIGH =   60 },
  CURVE =  { NONE =  0, EASY  =    2, MEDIUM =   4, HARD =    6 }
}

function Road.addSegment(curve, y)
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
      p1 = { world = { y= Road.lastY(), z =  n   *segmentLength }, camera = {}, screen = {} },
      p2 = { world = { y= y,       z = (n+1)*segmentLength }, camera = {}, screen = {} },
      curve = curve,
      cars = {},
      sprites = {},
      color = seg_color
    })
end	

function Road.addStraight(num) 
  num = num or ROAD.LENGTH.MEDIUM
  Road.addRoad(num, num, num, 0,  0)
end

function Road.addHill(num, height) 
  num    = num    or ROAD.LENGTH.MEDIUM
  height = height or ROAD.HILL.MEDIUM
  Road.addRoad(num, num, num, 0, height)
end

function Road.addLowRollingHills(num, height)
  num    = num    or ROAD.LENGTH.SHORT
  height = height or ROAD.HILL.LOW
  Road.addRoad(num, num, num,  0,  height/2)
  Road.addRoad(num, num, num,  0, -height)
  Road.addRoad(num, num, num,  0,  height)
  Road.addRoad(num, num, num,  0,  0)
  Road.addRoad(num, num, num,  0,  height/2)
  Road.addRoad(num, num, num,  0,  0)
end

function Road.addDownhillToEnd(num)
  num = num or 200
  Road.addRoad(num, num, num, -ROAD.CURVE.EASY, -Road.lastY()/segmentLength)
end

function Road.addCurve(num, curve, height) 
  num    = num    or ROAD.LENGTH.MEDIUM
  curve  = curve  or ROAD.CURVE.MEDIUM
  height = height or ROAD.HILL.NONE
  Road.addRoad(num, num, num, curve, height)
end

function Road.addSCurves() 
  Road.addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.EASY,    ROAD.HILL.NONE)
  Road.addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,   ROAD.CURVE.MEDIUM,  ROAD.HILL.MEDIUM)
  Road.addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,   ROAD.CURVE.EASY,   -ROAD.HILL.LOW)
  Road.addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.EASY,    ROAD.HILL.MEDIUM)
  Road.addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM)
end

function Road.lastY()
  local length = table.getn(segments)
  if length == 0 then
    return 0
  else
    local s = segments[length]
    return s.p2.world.y
  end
end

function Road.addRoad(enter, hold, leave, curve, y)
  local startY = Road.lastY()
  local endY = startY + (Util.toInt(y, 0) * segmentLength)
  local total = enter + hold + leave

  for n = 0, enter, 1 do
    Road.addSegment(Util.easeIn(0, curve, n/enter), Util.easeInOut(startY, endY, n/total))
  end
  for n = 0, hold, 1 do
    Road.addSegment(curve, Util.easeInOut(startY, endY, (enter+n)/total))
  end
  for n = 0, leave, 1 do 
    Road.addSegment(Util.easeInOut(curve, 0, n/leave), Util.easeInOut(startY, endY, (enter+hold+n)/total))
  end
end

function Road.resetRoad()
  segments = {}

  Road.addStraight(ROAD.LENGTH.SHORT/2)
  Road.addHill(ROAD.LENGTH.SHORT, ROAD.HILL.LOW)
  Road.addLowRollingHills()
  Road.addCurve(ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW)
  Road.addLowRollingHills()
  Road.addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM)
  Road.addStraight()
  Road.addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM)
  Road.addHill(ROAD.LENGTH.LONG, ROAD.HILL.HIGH)
  Road.addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW)
  Road.addHill(ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM)
  Road.addStraight()
  Road.addDownhillToEnd()

  segments[findSegment(playerZ).index + 1].color.road = Color.Start()
  segments[findSegment(playerZ).index + 2].color.road = Color.Start()

  local length = table.getn(segments) 
  for n = 0,rumbleLength, 1 do
    segments[length-n].color.road = Color.Finish()
  end

  trackLength = length * segmentLength
end

return Road