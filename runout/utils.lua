local Util = {}

function Util.interpolate(a,b,percent)
  return a + (b-a)*percent
end

function Util.easeIn(a,b,percent)
  return a + (b-a)*((-math.cos(percent*math.pi)/2) + 0.5)
end

function Util.easeOut(a,b,percent)
  return a + (b-a)*(1-math.pow(1-percent,2))
end

function Util.easeInOut(a,b,percent)
  return a + (b-a)*((-math.cos(percent*math.pi)/2) + 0.5)
end

function Util.exponentialFog(distance, density)
  local e = 2.718281828459045
  return 1.0 / (math.pow(e, (distance * distance * density)))
end

function Util.toInt(obj, def)
  if obj then
    local x = tonumber(obj, 10)
    if x then 
      return x - (x % 1)
    end
  end

  return Util.toInt(def, 0)
end

function Util.increase(start, increment, max)
  local result = start + increment
  while (result >= max) do
    result = result - max
  end
  while (result < 0) do
    result = result + max
  end
  return result
end

function Util.limit(value, min, max)
  return math.max(min, math.min(value, max)) 
end

function Util.accelerate(v, accel, dt)
  return v + (accel * dt)
end

function Util.percentRemaining(n, total)
  return (n%total)/total
end

function Util.project(p, cameraX, cameraY, cameraZ, cameraDepth, width, height, roadWidth)
  p.camera.x     = (p.world.x or 0) - cameraX
  p.camera.y     = (p.world.y or 0) - cameraY
  p.camera.z     = (p.world.z or 0) - cameraZ
  p.screen.scale = cameraDepth/p.camera.z
  p.screen.x     = math.ceil((width/2)  + (p.screen.scale * p.camera.x  * width/2))
  p.screen.y     = math.ceil((height/2) - (p.screen.scale * p.camera.y  * height/2))
  p.screen.w     = math.ceil(             (p.screen.scale * roadWidth   * width/2))
end

function Util.overlap(x1, w1, x2, w2, percent)
  local half = (percent or 1)/2
  local min1 = x1 - (w1*half)
  local max1 = x1 + (w1*half)
  local min2 = x2 - (w2*half)
  local max2 = x2 + (w2*half)
  return not ((max1 < min2) or (min1 > max2))
end

return Util