local SPRITES = {}

local Util = require 'utils'
local Render = require 'render'
local Road = require 'road'
local Color = require 'color'
local Cars = require 'cars'

function love.load()
  -- attach a debugger \o/
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  fps           = 60                      -- how many 'update' frames per second
  step          = 1/fps                   -- how long is each frame (in seconds)
  width         = 640                    -- logical canvas width
  height        = 480                     -- logical canvas height
  segments      = {}                      -- array of road segments
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


  player = love.graphics.newImage('player.png')
  car1 = love.graphics.newImage('car1.png')
  car2 = love.graphics.newImage('car2.png')
  car3 = love.graphics.newImage('car3.png')
  car4 = love.graphics.newImage('car4.png')

  billboard = love.graphics.newImage('billboard.png')

  playerW = player:getWidth() 
  SPRITES.SCALE = 0.3 * (1/playerW)
  scaledPlayerW = player:getWidth() * SPRITES.SCALE

  cars      = {}  -- array of cars on the road
  totalCars = 200 -- total number of cars on the road

  Road.reset()
  Cars.reset(SPRITES.SCALE)
end

function love.update(dt)
  if love.keyboard.isDown('left',  'a') then keyLeft   = true end
  if love.keyboard.isDown('right', 'd') then keyRight  = true end
  if love.keyboard.isDown('up',    'w') then keyFaster = true end
  if love.keyboard.isDown('down',  's') then keySlower = true end

  local playerSegment = findSegment(position+playerZ)
  local speedPercent  = speed/maxSpeed
  local dx            = dt * 2 * speedPercent -- at top speed, should be able to cross from left to right (-1 to 1) in 1 second

  Cars.update(dt, playerSegment, playerW)

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
    carW = scaledPlayerW
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
      spriteX     = segment.p1.screen.x + (spriteScale * sprite.offset * (roadWidth + 1500) * width/2)
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

function findSegment(z)
  local index = math.floor(z/segmentLength) % table.getn(segments)
  -- offset by 1 because lua's tables aren't 0 based
  return segments[index + 1]
end
