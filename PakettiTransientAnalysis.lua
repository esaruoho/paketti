-- FEATURE-CARD >> features/transient-integration.feature
-- Level-rise/treble detection adapted from Phaos & Claude SimpleTransients 1.0.3.
-- Pure analysis module: no Renoise observers, selection writes or slice markers.
local M = {}
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function db(power) return 10 * math.log(power + 1e-12) / math.log(10) end

function M.detect(buf, options, yield_progress)
  local prefs = {}
  for k,v in pairs(options) do prefs[k] = {value=v} end
  local C = {PEAK_MS=25, ZC_MS=3}
  function C.rise_for(sens) return 1.5 + (1 - clamp(sens,0,100)/100)*22.5 end
  local A = {}
function A.pick(c)
  local p, q, H = c.p, c.q, c.H
  local K = #p
  local rise_min = C.rise_for(prefs.sensitivity.value)
  local floor_db = db(c.maxp) - prefs.threshold.value
  local function pre(t, k)            -- mean of the three hops before k, dB
    local s, cnt = 0, 0
    for j = math.max(1, k - 3), k - 1 do s = s + t[j] cnt = cnt + 1 end
    return db(s / cnt)
  end
  local rise = { [1] = 0 }
  for k = 2, K do
    local r = 0
    local post = db(math.max(p[k], p[k + 1] or 0))
    if post >= floor_db then
      local postq = db(math.max(q[k], q[k + 1] or 0))
      r = math.max(post - pre(p, k), postq - pre(q, k))
    end
    rise[k] = r
  end
  -- local maxima that jump far enough
  local cands = {}
  for k = 2, K do
    local r = rise[k]
    if r >= rise_min then
      local top = true
      for j = math.max(2, k - 2), math.min(K, k + 2) do
        if j ~= k and (rise[j] > r or (rise[j] == r and j < k)) then
          top = false
          break
        end
      end
      if top then cands[#cands + 1] = { k = k, r = r } end
    end
  end
  -- Min gap: the strongest hits first, then whatever still fits in between
  table.sort(cands, function(x, y)
    if x.r ~= y.r then return x.r > y.r end
    return x.k < y.k
  end)
  local gap = math.max(1, math.floor(prefs.min_gap_ms.value / 1000
                                     * c.rate / H + 0.5))
  local taken, ks = {}, {}
  for _, cd in ipairs(cands) do
    local free = true
    for j = cd.k - gap + 1, cd.k + gap - 1 do
      if taken[j] then free = false break end
    end
    if free then taken[cd.k] = true ks[#ks + 1] = cd.k end
  end
  table.sort(ks)
  local points = {}
  for i, k in ipairs(ks) do points[i] = (k - 1) * H + 1 end
  c.points = points
  c.refined, c.ref_next = {}, 1
end

function A.refine(buf, f, H)
  local n = buf.number_of_frames
  local chs = math.min(2, buf.number_of_channels)
  local rate = buf.sample_rate
  local peak_frames = math.floor(C.PEAK_MS / 1000 * rate)
  local L = math.max(32, math.floor(rate * 0.003))
  local a = math.max(1, f - 4 * H)
  local e = math.min(n, f + 3 * H + L)              -- the range examined
  local b = math.min(n, e + peak_frames)             -- frames read
  local mono, mag, power, treble = {}, {}, {}, {}
  local previous = {}
  for i = a, b do
    local mx, signed, energy, flux = -1, 0, 0, 0
    for c = 1, chs do
      local v = buf:sample_data(c, i)
      local d = v - (previous[c] or v)
      previous[c] = v
      energy, flux = energy + v*v, flux + d*d
      if math.abs(v) > mx then mx, signed = math.abs(v), v end
    end
    mono[i], mag[i], power[i], treble[i] = signed, mx, energy / chs, flux / chs
  end
  -- running sums of the power of the signal (S1) and of its treble (S2)
  local a0 = a + 1
  local S1, S2 = { [a] = 0 }, { [a] = 0 }
  for i = a0, e do
    S1[i] = S1[i - 1] + power[i]
    S2[i] = S2[i - 1] + treble[i]
  end
  local f0, best = nil, 0
  local t_lo = math.max(a0 + L, f - H)
  local t_hi = math.min(e - L + 1, f + 3 * H)
  local N = e - a0 + 1
  local eps = 1e-14
  for _, Sx in ipairs { S1, S2 } do
    local total = Sx[e] - Sx[a]
    local base = N * math.log(total / N + eps)
    for t = t_lo, t_hi do
      local n1, n2 = t - a0, e - t + 1
      local s1 = Sx[t - 1] - Sx[a]
      local m1, m2 = s1 / n1 + eps, (total - s1) / n2 + eps
      if m2 > m1 then
        local gain = base - n1 * math.log(m1) - n2 * math.log(m2)
        if gain > best then best, f0 = gain, t end
      end
    end
  end
  if not f0 then return clamp(f, 1, n) end
  if prefs.snap_mode.value == 2 then
    -- "Peak": the loudest frame of the hit
    local last = math.min(b, f0 + peak_frames)
    local top, at = -1, f0
    for i = f0, last do if mag[i] > top then top, at = mag[i], i end end
    return at
  end
  if prefs.zero_cross.value then
    -- onto the nearest zero crossing before it
    local stop = math.max(a + 1, f0 - math.floor(C.ZC_MS / 1000 * rate))
    for i = f0, stop, -1 do
      local x, y = mono[i - 1], mono[i]
      if y == 0 or (x < 0) ~= (y < 0) then
        if math.abs(x) < math.abs(y) then return i - 1 end
        return i
      end
    end
  end
  return f0
end


  local n, rate = buf.number_of_frames, buf.sample_rate
  local H = math.max(32, math.floor(rate * 0.005 + 0.5))
  local chs = math.min(2, buf.number_of_channels)
  local c = {H=H, rate=rate, p={}, q={}, maxp=0}
  local previous = {}
  local hops = math.ceil(n/H)
  for k=1,hops do
    local a,b=(k-1)*H+1, math.min(n,k*H)
    local energy,flux=0,0
    for channel=1,chs do
      local prev=previous[channel] or 0
      for frame=a,b do
        local v=buf:sample_data(channel,frame)
        energy,flux=energy+v*v,flux+(v-prev)*(v-prev)
        prev=v
      end
      previous[channel]=prev
    end
    local count=(b-a+1)*chs
    c.p[k],c.q[k]=energy/count,flux/count
    c.maxp=math.max(c.maxp,c.p[k])
    if k % 16 == 0 and yield_progress then yield_progress(k/hops*0.8) end
  end
  A.pick(c)
  local positions={}
  for i,f in ipairs(c.points) do
    positions[#positions+1]=A.refine(buf,f,H)
    if i % 8 == 0 and yield_progress then yield_progress(0.8+i/math.max(1,#c.points)*0.2) end
  end
  table.sort(positions)
  local result={}
  for _,f in ipairs(positions) do
    if f~=(result[#result] or 0) then result[#result+1]=f end
  end
  return result
end
return M
