local function clamp(n, lo, hi)
  n = tonumber(n)
  if not n then return lo end
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function randf(lo, hi)
  return lo + (math.random() * (hi - lo))
end

local function wrap(v, lo, hi)
  if v < lo then return hi - (lo - v) end
  if v > hi then return lo + (v - hi) end
  return v
end

local function dist2(x1,y1,x2,y2)
  local dx, dy = x2-x1, y2-y1
  return dx*dx + dy*dy
end

local function headingDeg(fromX, fromY, toX, toY)
  return math.deg(math.atan2(toY - fromY, toX - fromX))
end

AZW = {
  clamp = clamp,
  lerp = lerp,
  randf = randf,
  wrap = wrap,
  dist2 = dist2,
  headingDeg = headingDeg,
}
