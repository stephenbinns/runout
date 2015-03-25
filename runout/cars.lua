local Cars = {}
local Util = require 'utils'
local SCALE

function Cars.reset(sprite_scale)
  cars = {}
  SCALE = sprite_scale
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

function Cars.update(dt, playerSegment, playerW)
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
  local carW = car.sprite:getWidth() * SCALE

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

return Cars