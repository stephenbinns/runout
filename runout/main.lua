local Util = require 'utils'
local Render = require 'render'
local Color = require 'color'
local SPRITES = {}

function love.load()
  -- attach a debugger \o/
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  fps           = 60                      -- how many 'update' frames per second
  step          = 1/fps                   -- how long is each frame (in seconds)
  width         = 640                    -- logical canvas width
  height        = 480                     -- logical canvas height
  segments      = {}                      -- array of road segments
  background    = nil                    -- our background image (loaded below)
  sprites       = nil                    -- our spritesheet (loaded below)
  resolution    = nil                    -- scaling factor to provide resolution independence (computed)
  roadWidth     = 2000                    -- actually half the roads width, easier math if the road spans from -roadWidth to +roadWidth
  segmentLength = 200                     -- length of a single segment
  rumbleLength  = 3                       -- number of segments per red/white rumble strip
  trackLength   = nil                    -- z length of entire track (computed)
  lanes         = 3                       -- number of lanes
  fieldOfView   = 100                     -- angle (degrees) for field of view
  cameraHeight  = 1000                    -- z height of camera
  cameraDepth   = 1 / math.tan((fieldOfView/2) * math.pi/180) -- z distance camera is from screen (computed)
  drawDistance  = 500                     -- number of segments to draw
  playerX       = 0                       -- player x offset from center of road (-1 to 1 to stay independent of roadWidth)
  playerZ       = nil                    -- player relative z distance from camera (computed)
  fogDensity    = 5                       -- exponential fog density
  position      = 1                       -- current camera Z position (add playerZ to get player's absolute Z position)
  speed         = 0                       -- current speed
  maxSpeed      = segmentLength/step      -- top speed (ensure we can't move more than 1 segment in a single frame to make collision detection easier)
  accel         =  maxSpeed/5             -- acceleration rate - tuned until it 'felt' right
  breaking      = -maxSpeed               -- deceleration rate when braking
  decel         = -maxSpeed/5             -- 'natural' deceleration rate when neither accelerating, nor braking
  offRoadDecel  = -maxSpeed/2             -- off road deceleration is somewhere in between
  offRoadLimit  =  maxSpeed/4             -- limit when off road deceleration no longer applies (e.g. you can always go at least this speed even when off road)

  playerZ       = (cameraHeight * cameraDepth)
  centrifugal   = 0.35                     -- centrifugal force multiplier when going around curves
  resolution    = height/480
  resetRoad()

  player = love.graphics.newImage('player.png')
  car1 = love.graphics.newImage('car1.png')
  car2 = love.graphics.newImage('car2.png')
  car3 = love.graphics.newImage('car3.png')
  car4 = love.graphics.newImage('car4.png')

  playerW = player:getWidth() 
  SPRITES.SCALE = 0.3 * (1/playerW)
  scaledPlayerW = player:getWidth() * SPRITES.SCALE

  cars      = {}  -- array of cars on the road
  totalCars = 200 -- total number of cars on the road
  resetCars()
end

function love.update(dt)
  if love.keyboard.isDown('left',  'a') then keyLeft   = true end
  if love.keyboard.isDown('right', 'd') then keyRight  = true end
  if love.keyboard.isDown('up',    'w') then keyFaster = true end
  if love.keyboard.isDown('down',  's') then keySlower = true end

  local playerSegment = findSegment(position+playerZ)
  local speedPercent  = speed/maxSpeed
  local dx            = dt * 2 * speedPercent -- at top speed, should be able to cross from left to right (-1 to 1) in 1 second

  updateCars(dt, playerSegment, playerW)

  position = Util.increase(position, dt * speed, trackLength)

  if (keyLeft) then
    playerX = playerX - dx
  elseif (keyRight) then
    playerX = playerX + dx
  end

  if (keyFaster) then
    speed = Util.accelerate(speed, accel, dt)
  elseif (keySlower) then
    speed = Util.accelerate(speed, breaking, dt)
  else 
    speed = Util.accelerate(speed, decel, dt)
  end

  playerX = playerX - (dx * speedPercent * playerSegment.curve * centrifugal)

  -- if player leaves road
  if (((playerX < -1) or (playerX > 1)) and (speed > offRoadLimit)) then
    speed = Util.accelerate(speed, offRoadDecel, dt)
  end

  for n = 1, table.getn(playerSegment.cars), 1 do
    car  = playerSegment.cars[n]
    carW = scaledPlayerW--car.sprite:getWidth() * SPRITES.SCALE
    if (speed > car.speed) then
      if (Util.overlap(playerX, scaledPlayerW, car.offset, carW, 0.5)) then
        speed    = car.speed * (car.speed/speed)
        position = Util.increase(car.z, -playerZ, trackLength)
        break
      end
    end
  end

  playerX = Util.limit(playerX, -2, 2)     -- dont ever let player go too far out of bounds
  speed   = Util.limit(speed, 0, maxSpeed) -- or exceed maxSpeed
end

function love.keyreleased(key)
  if key == "escape" then
    love.event.quit()
  end

  if key == 'left'  then keyLeft   = false end
  if key == 'a'     then keyLeft   = false end
  if key == 'right' then keyRight  = false end
  if key == 'd'     then keyRight  = false end
  if key == 'up'    then keyFaster = false end
  if key == 'w'     then keyFaster = false end
  if key == 'down'  then keySlower = false end
  if key == 's'     then keySlower = false end
end

function love.draw()
  local baseSegment   = findSegment(position)
  local basePercent   = Util.percentRemaining(position, segmentLength)
  local playerSegment = findSegment(position+playerZ)
  local playerPercent = Util.percentRemaining(position+playerZ, segmentLength)
  local playerY       = Util.interpolate(playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent)

  local maxy          = height
  local segment
  local segmentsLength = table.getn(segments)
  local x = 0
  local dx = - (baseSegment.curve * basePercent)

  Render.background(Color.Background())

  for n = 0, drawDistance, 1 do
    local index = ((baseSegment.index + n) % segmentsLength) 

    segment = segments[index + 1] 
    segment.looped = segment.index < baseSegment.index
    segment.fog = Util.exponentialFog(n/drawDistance, fogDensity)
    segment.clip = maxy

    offset = 0
    if segment.looped then
      offset = trackLength
    end

    Util.project(segment.p1, (playerX * roadWidth) - x, playerY + cameraHeight, position - offset, cameraDepth, width, height, roadWidth)
    Util.project(segment.p2, (playerX * roadWidth) - x - dx, playerY + cameraHeight, position - offset, cameraDepth, width, height, roadWidth)

    x  = x + dx
    dx = dx + segment.curve

    if not ((segment.p1.camera.z <= cameraDepth) or -- behind us
      (segment.p2.screen.y >= segment.p1.screen.y) or
      (segment.p2.screen.y >= maxy)) then -- clip by (already rendered) segment
      Render.segment(width, lanes,
        segment.p1.screen.x,
        segment.p1.screen.y,
        segment.p1.screen.w,
        segment.p2.screen.x,
        segment.p2.screen.y,
        segment.p2.screen.w,
        segment.color,
        segment.fog)

      maxy = segment.p2.screen.y
    end
  end
  --back to front painters algorithm
  for n = (drawDistance-1), 0, -1 do
    local index = ((baseSegment.index + n) % segmentsLength) 
    segment = segments[index + 1] 

    -- render roadside sprites
    local i
    local nsprites = table.getn(segment.sprites)
    for i = 1, nsprites, 1 do
      sprite      = segment.sprites[i]
      spriteScale = segment.p1.screen.scale
      spriteX     = segment.p1.screen.x + (spriteScale * sprite.offset * roadWidth * width/2)
      spriteY     = segment.p1.screen.y
      local offset
      if sprite.offset < 0 then offset = -1 else offset = 0 end
      Render.sprite(width, height, resolution, roadWidth, sprites, sprite.source, spriteScale, spriteX, spriteY, offset, -1, segment.clip)
    end

    -- render other cars
    local i
    local ncars = table.getn(segment.cars)
    for i = 1, ncars, 1 do
      car         = segment.cars[i]
      sprite      = car.sprite
      spriteScale = Util.interpolate(segment.p1.screen.scale, segment.p2.screen.scale, car.percent)
      spriteX     = Util.interpolate(segment.p1.screen.x,     segment.p2.screen.x,     car.percent) + (spriteScale * car.offset * roadWidth * width/2)
      spriteY     = Util.interpolate(segment.p1.screen.y,     segment.p2.screen.y,     car.percent)
      Render.sprite(width, height, resolution, roadWidth, sprites, car.sprite, spriteScale, spriteX, spriteY, -0.5, -1, segment.clip)
    end

  end

  local steer = 0
  if keyLeft then
    steer = -1 
  elseif keyRight then
    steer = 1
  end

  Render.player(width, height, resolution, roadWidth, sprites, speed/maxSpeed,
    cameraDepth/playerZ,
    width/2,
    (height/2) - (cameraDepth/playerZ * Util.interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * height/2),
    steer,
    playerSegment.p2.world.y - playerSegment.p1.world.y)
end

-- probably remove this for production version
local function error_printer(msg, layer)
  print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function findSegment(z)
  local index = math.floor(z/segmentLength) % table.getn(segments)
  -- offset by 1 because lua's tables aren't 0 based
  return segments[index + 1]
end

local ROAD = {
  LENGTH = { NONE =  0, SHORT =   25, MEDIUM =  50, LONG =  100 },
  HILL   = { NONE =  0, LOW   =   20, MEDIUM =  40, HIGH =   60 },
  CURVE =  { NONE =  0, EASY  =    2, MEDIUM =   4, HARD =    6 }
}

function resetCars()
  cars = {}
  local n, car, segment, offset, z, sprite, speed, selection
  local segmentsLength = table.getn(segments)

  for  n = 0, totalCars, 1 do
    selection = math.random()
    if selection < 0.5 then
      offset = math.random() * -0.8
    else
      offset = math.random() * 0.8
    end

    z = math.floor(math.random() * segmentsLength) * segmentLength
    selection = n % 4
    if selection == 0 then
      sprite = car1
    elseif selection == 1 then
      sprite = car2
    elseif selection == 2 then
      sprite = car3
    elseif selection == 3 then
      sprite = car4
    end

    speed  = maxSpeed / 4 + math.random() * maxSpeed / 2
    car = { offset = offset, z = z, sprite = sprite, speed = speed }

    segment = findSegment(car.z)
    table.insert(segment.cars, car)
    table.insert(cars, car)
  end
end

function updateCars(dt, playerSegment, playerW)
  local n, car, oldSegment, newSegment
  local ncars = table.getn(cars)
  for n = 1, ncars, 1 do
    car         = cars[n]
    oldZ = car.z
    oldSegment  = findSegment(car.z)
    car.offset  = car.offset + updateCarOffset(car, oldSegment, playerSegment, playerW)
    car.z       = Util.increase(car.z, (dt * car.speed) , trackLength)
    car.percent = Util.percentRemaining(car.z, segmentLength) -- useful for interpolation during rendering phase
    newSegment  = findSegment(car.z)

    if not (oldSegment.index == newSegment.index) then 
      local index
      for i, v in ipairs(oldSegment.cars) do
        if v == car then
          index = i
          break
        end
      end
      table.remove(oldSegment.cars, index)
      table.insert(newSegment.cars, car)
    end
  end
end

function updateCarOffset(car, carSegment, playerSegment, playerW)

  local i, j, dir, segment, otherCar, otherCarW
  local lookahead = 20
  local carW = car.sprite:getWidth() * SPRITES.SCALE

  --optimization, dont bother steering around other cars when 'out of sight' of the player
  if ((carSegment.index - playerSegment.index) > drawDistance) then
    return 0
  end

  local segLen = table.getn(segments)
  for i = 1, lookahead, 1 do
    index = (carSegment.index+i)%segLen + 1
    segment = segments[index]

    if ((segment == playerSegment) and (car.speed > speed) and (Util.overlap(playerX, playerW, car.offset, carW, 1.2))) then
      if (playerX > 0.5) then
        dir = -1
      elseif (playerX < -0.5) then
        dir = 1
      else
        if car.offset > playerX then
          dir = 1
        else
          dir = -1
        end
      end

      return dir * 1/i * (car.speed-speed)/maxSpeed -- the closer the cars (smaller i) and the greater the speed ratio, the larger the offset
    end

    for j = 1, table.getn(segment.cars), 1 do
      otherCar  = segment.cars[j]
      if ((car.speed > otherCar.speed) and Util.overlap(car.offset, carW, otherCar.offset, scaledPlayerW, 1.2)) then
        if (otherCar.offset > 0.5) then
          dir = -1
        elseif (otherCar.offset < -0.5) then
          dir = 1
        else
          if car.offset > playerX then
            dir = 1
          else
            dir = -1
          end
        end
        return dir * 1/i * (car.speed-otherCar.speed)/maxSpeed
      end
    end
  end
  -- if no cars ahead, but I have somehow ended up off road, then steer back on
  if (car.offset < -0.9) then
    return 0.1
  elseif (car.offset > 0.9) then
    return -0.1
  else
    return 0
  end
end

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
  num = num or ROAD.LENGTH.MEDIUM
  addRoad(num, num, num, 0,  0)
end

function addHill(num, height) 
  num    = num    or ROAD.LENGTH.MEDIUM
  height = height or ROAD.HILL.MEDIUM
  addRoad(num, num, num, 0, height)
end

function addLowRollingHills(num, height)
  num    = num    or ROAD.LENGTH.SHORT
  height = height or ROAD.HILL.LOW
  addRoad(num, num, num,  0,  height/2)
  addRoad(num, num, num,  0, -height)
  addRoad(num, num, num,  0,  height)
  addRoad(num, num, num,  0,  0)
  addRoad(num, num, num,  0,  height/2)
  addRoad(num, num, num,  0,  0)
end

function addDownhillToEnd(num)
  num = num or 200
  addRoad(num, num, num, -ROAD.CURVE.EASY, -lastY()/segmentLength)
end

function addCurve(num, curve, height) 
  num    = num    or ROAD.LENGTH.MEDIUM
  curve  = curve  or ROAD.CURVE.MEDIUM
  height = height or ROAD.HILL.NONE
  addRoad(num, num, num, curve, height)
end

function addSCurves() 
  addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.EASY,    ROAD.HILL.NONE)
  addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,   ROAD.CURVE.MEDIUM,  ROAD.HILL.MEDIUM)
  addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,   ROAD.CURVE.EASY,   -ROAD.HILL.LOW)
  addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.EASY,    ROAD.HILL.MEDIUM)
  addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM,  -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM)
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

function resetRoad()
  segments = {}

  addStraight(ROAD.LENGTH.SHORT/2)
  addHill(ROAD.LENGTH.SHORT, ROAD.HILL.LOW)
  addLowRollingHills()
  addCurve(ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW)
  addLowRollingHills()
  addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM)
  addStraight()
  addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM)
  addHill(ROAD.LENGTH.LONG, ROAD.HILL.HIGH)
  addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW)
  addHill(ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM)
  addStraight()
  addDownhillToEnd()

  segments[findSegment(playerZ).index + 1].color.road = Color.Start()
  segments[findSegment(playerZ).index + 2].color.road = Color.Start()

  local length = table.getn(segments) 
  for n = 0,rumbleLength, 1 do
    segments[length-n].color.road = Color.Finish()
  end

  trackLength = length * segmentLength
end
