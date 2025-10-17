-- Chebyshev Waveshaper for Paketti
-- Advanced polynomial waveshaping with real-time preview

-- OPTIMIZATION: Localize hot math functions (avoid table lookups in tight loops)
local abs, min, max, floor = math.abs, math.min, math.max, math.floor

local vb = renoise.ViewBuilder()
local dialog = nil
-- Harmonic gains for harmonics 2-13 (skip DC and fundamental)  
local harmonic_gains = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0} -- H2-H13, all start at 0
local oversampling_factor = 1 -- 1x, 2x, 4x, 8x
local dry_value = 1.0
local wet_value = 1.0  -- FIXED: Default to 100% wet (much better UX!)  
-- Bézier curve control points for pre-warping
local curve_yL = -1.0  -- Left control point 
local curve_yC = 0.0   -- Center control point
local curve_yR = 1.0   -- Right control point  
local output_gain_value = 1.0
local auto_normalize_enabled = false
local preview_enabled = false
local backup_sample_data = nil
local backup_sample_properties = nil
local backup_range = nil  -- {start_frame, end_frame}

-- ==== Magnet Shaper parameters (global) =====================================
local shaper_mode = "cheby"   -- "cheby" or "magnet"

local mag_drive      = 1.0    -- 0..+inf (we map to sensible range)
local mag_tilt       = 0.0    -- -1..+1 (tone bias)
local mag_tilt_bias  = 0.0    -- -1..+1 (asymmetry between pos/neg)
local mag_tilt_limit = 0.5    -- 0..1  (slew limit amount; 0 = brick slow, 1 = wide open)
local mag_feedback   = 0.0    -- 0..1  (how much previous y bends the tilt)
local mag_out        = 1.0    -- 0.1..2.0 (post trim)

-- Canvas state variables
local parameter_canvas = nil
local waveform_canvas = nil
local waveform_canvas_width = 780  -- Wider to accommodate 13 sliders
local waveform_canvas_height = 200
local parameter_canvas_width = waveform_canvas_width
local parameter_canvas_height = 300  -- Taller for harmonic sliders
local is_dragging_param = false
local drag_param_type = nil -- "harmonic1", "harmonic2", ... "harmonic13"

-- Double-click detection variables
local last_click_time = 0
local last_click_x = 0
local last_click_y = 0
local double_click_threshold = 500  -- milliseconds

-- Cached waveform data for display
local original_waveform_cache = nil
local processed_waveform_cache = nil

-- Canvas references
local parameter_canvas = nil
local waveform_canvas = nil
local bezier_canvas = nil  -- NEW: Bézier curve visualization canvas

-- Backup data for preview mode
local backup_sample_data = nil
local backup_range = nil


-- Debouncing system for performance
local dirty = false
local last_change_ms = 0
local last_mouse_ms = 0  -- For adaptive debouncing

-- OPTIMIZATION: Get current time once (avoid repeated os.clock calls)
local function now_ms() return os.clock() * 1000 end

-- Oversampling values array for robust UI mapping
local OS_VALUES = {0, 1, 2, 4}  -- 0 = Auto oversampling (removed 8x - too slow!)

-- Performance optimization helpers
local function is_all_zero(harmonic_table)
  for i = 1, 12 do 
    if harmonic_table[i] ~= 0.0 then return false end 
  end
  return true
end

local function is_curve_identity()
  return (curve_yL == -1.0 and curve_yC == 0.0 and curve_yR == 1.0)
end

local function highest_active_harmonic()
  local k = 0
  for i = 12, 1, -1 do 
    if harmonic_gains[i] ~= 0.0 then 
      k = i + 1  -- Harmonic number (H2 = i+1)
      break 
    end 
  end
  return k
end

local function choose_auto_oversampling()
  local K = highest_active_harmonic()
  if K <= 3 then return 1   -- H2-H3: No aliasing risk 
  elseif K <= 5 then return 2   -- H4-H5: 2x oversampling sufficient
  else return 4 end              -- H6+: 4x maximum (8x was too slow!)
end

local function curve_has_dc()
  -- Cheap symmetry test - skip DC blocker for symmetric curves
  return (math.abs(curve_yL + curve_yR) > 1e-6) or (math.abs(curve_yC) > 1e-6)
end

-- Parameter hash for smart rebuilding
local last_param_hash = ""
local function param_hash()
  -- Debug: Check if shaper_mode is accessible
  local mode = shaper_mode or "cheby"
  return table.concat({
    tostring(mode),
    string.format("%.5f,%.5f,%.5f", curve_yL, curve_yC, curve_yR),
    table.concat(harmonic_gains, ","),
    tostring(wet_value), tostring(dry_value), tostring(output_gain_value),
    tostring(oversampling_factor),
    -- Magnet parameters (with fallbacks)
    string.format("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f", 
      mag_drive or 1.0, mag_tilt or 0.0, mag_tilt_bias or 0.0, 
      mag_tilt_limit or 0.5, mag_feedback or 0.0, mag_out or 1.0)
  }, "|")
end

-- Precomputed slider colors (avoid sin/cos every render!)
local SLIDER_COLORS = {}
local function precompute_slider_colors()
  for i = 1, 12 do
    local hue = (i - 1) * 30  -- Spread across spectrum
    local r = math.floor(128 + 100 * math.sin(math.rad(hue)))
    local g = math.floor(128 + 100 * math.sin(math.rad(hue + 120)))
    local b = math.floor(128 + 100 * math.sin(math.rad(hue + 240)))
    
    -- Ensure valid range
    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))
    
    SLIDER_COLORS[i] = {r, g, b}
  end
end
precompute_slider_colors()  -- Compute once at startup

-- OPTIMIZATION: Lazy-initialized bulk-copy capability flag (eliminate repeated pcall cost)
local HAS_BULK = nil

local function check_bulk_capability()
  if HAS_BULK == nil then
    local s = renoise.song().selected_sample
    if not s or not s.sample_buffer then 
      HAS_BULK = false 
    else
      local ok = pcall(function() 
        s.sample_buffer:copy_channel_data_to_table(1, 1, 1, {}) 
      end)
      HAS_BULK = ok
    end
  end
  return HAS_BULK
end

-- OPTIMIZATION: Per-channel processing state (reused across chunks for continuity)
local PROC_STATE = {}  -- ch -> {up_hist={}, down_hist={}, dc_x1=0.0, dc_y1=0.0}

local function get_state(ch, hist_len)
  local s = PROC_STATE[ch]
  if not s then 
    -- BUGFIX: Pre-allocate history buffers to correct size from the start
    s = {up_hist={}, down_hist={}, dc_x1=0.0, dc_y1=0.0}
    -- Initialize both arrays to the required length with zeros
    for i = 1, hist_len do
      s.up_hist[i] = 0.0
      s.down_hist[i] = 0.0
    end
    PROC_STATE[ch] = s 
  else
    -- Ensure histories are long enough (extend if needed)
    if #s.up_hist < hist_len then 
      for i = #s.up_hist + 1, hist_len do s.up_hist[i] = 0.0 end 
    end
    if #s.down_hist < hist_len then 
      for i = #s.down_hist + 1, hist_len do s.down_hist[i] = 0.0 end 
    end
  end
  return s
end

-- OPTIMIZATION: Reusable scratch buffers (eliminate allocations)
local INBUF, OUTBUF = {}, {}

-- OPTIMIZATION: Fast bulk read/write using probed capability (eliminate repeated pcalls)
local function read_chunk(dst, buffer, ch, start_frame, end_frame)
  local N = end_frame - start_frame + 1
  if check_bulk_capability() then
    buffer:copy_channel_data_to_table(ch, start_frame, end_frame, dst)
  else
    for i = 1, N do 
      dst[i] = buffer:sample_data(ch, start_frame + i - 1) 
    end
  end
  -- Trim dst table to exact size
  for i = N + 1, #dst do dst[i] = nil end
  return N
end

local function write_chunk(src, buffer, ch, start_frame)
  if check_bulk_capability() then
    buffer:copy_channel_data_from_table(ch, start_frame, src)
  else
    for i = 1, #src do 
      buffer:set_sample_data(ch, start_frame + i - 1, src[i]) 
    end
  end
end

-- OPTIMIZATION: Adaptive chunk sizing - bigger chunks = fewer calls = faster!
local function get_optimal_chunk_size(oversampling_factor)
  local base = 262144  -- 256K base
  local actual_os = oversampling_factor == 0 and choose_auto_oversampling() or oversampling_factor
  return max(32768, floor(base / max(1, actual_os)))  -- Scale down for higher OS
end

-- DEAD CODE REMOVED: cheby_T is no longer needed (Clenshaw handles all polynomials)

local function build_transfer(coeffs) -- coeffs[2..13]
  return function (x)
    local y = 0.0
    for n = 2, 13 do
      local c = coeffs[n] or 0.0
      if c ~= 0.0 then y = y + c * cheby_T(n, x) end
    end
    return y
  end
end

-- O(N) Clenshaw evaluation for Chebyshev series (much faster than O(N²))
-- OPTIMIZED: Trim Clenshaw order to highest active harmonic (faster LUT build!)
local function make_series_clenshaw(coeffs, N)
  N = N or 13
  local c0 = coeffs[0] or 0.0
  return function(x)
    local b1, b2 = 0.0, 0.0
    for k = N, 1, -1 do
      local ck = coeffs[k] or 0.0
      local b0 = 2.0*x*b1 - b2 + ck
      b2, b1 = b1, b0
    end
    return x*b1 - b2 + c0
  end
end

-- OPTIMIZED: Build LUT and normalize in single pass (eliminates 8-16K probe sweep!)
local function make_lut_normalized(f_raw, size)
  size = size or 4096
  local lut, maxabs = {}, 0.0
  
  -- Single pass: build LUT and track peak
  for i=0,size-1 do
    local x = -1 + 2*(i/(size-1))
    local y = f_raw(x)
    lut[i+1] = y
    local a = y >= 0 and y or -y  -- Faster abs
    if a > maxabs then maxabs = a end
  end
  
  -- Scale LUT in-place to 0.99 peak
  local g = (maxabs > 0) and (0.99 / maxabs) or 1.0
  if g ~= 1.0 then
    for i=1,size do 
      lut[i] = lut[i] * g 
    end
  end
  
  return lut, g
end

-- OPTIMIZED: Create fast LUT evaluator with cached constants
local function make_lut_eval(lut)
  local scale = 0.5 * (#lut - 1)
  local offset = 0.5 * (#lut - 1) 
  local last = #lut
  
  return function(x)
    -- Fast clamp + linear interp (cached scale/offset avoids #, mults)
    if x <= -1 then return lut[1] elseif x >= 1 then return lut[last] end
    local t = x * scale + offset
    local i = math.floor(t); local frac = t - i
    local a = lut[i + 1]; local b = lut[i + 2]
    return a + (b - a) * frac
  end
end

-- === Curve control (-1, 0, +1) as piecewise quadratic Bézier ===============
-- Two arcs: [-1..0] and [0..+1]. Control points at x = -1, 0, +1 map to user yL,yC,yR.
-- This is cheap, smooth, monotonic-ish for reasonable settings, and lets you add asymmetry.
local function make_precurve(yL, yC, yR)
  -- Clamp to [-1,1] so we don't explode before normalization
  local function clamp(u) if u > 1 then return 1 elseif u < -1 then return -1 else return u end end
  yL, yC, yR = clamp(yL or -1), clamp(yC or 0), clamp(yR or 1)

  -- Quadratic Bézier utility
  local function bez2(p0, p1, p2, t)
    local u = 1 - t
    return u*u*p0 + 2*u*t*p1 + t*t*p2
  end

  return function (x)
    if x <= 0 then
      -- map x∈[-1,0] -> t∈[0,1]
      local t = (x + 1.0)
      return bez2(yL,  (yL + yC)*0.5, yC, t)
    else
      local t = x
      return bez2(yC,  (yC + yR)*0.5, yR, t)
    end
  end
end

-- DEAD CODE REMOVED: normalize_fn is no longer needed (LUT handles normalization)

-- === Small half-band FIRs for (cheap) oversampling ==========================
-- 2x half-band LPF (linear phase), 15 taps, ~80 dB stopband (coefs are symmetric).
-- Center tap ~0.5; zeros at odd taps except center (half-band property).
local HB15 = { -0.0010, 0.0000, 0.0078, 0.0000, -0.0310, 0.0000, 0.1220,
               0.5004,
               0.1220, 0.0000, -0.0310, 0.0000, 0.0078, 0.0000, -0.0010 }

-- Pre-split half-band FIR into even/odd polyphase (do once)
local function split_polyphase(h)
  local he, ho = {}, {}
  for i=1,#h do
    if (i % 2)==1 then he[#he+1]=h[i] else ho[#ho+1]=h[i] end
  end
  return he, ho
end
local HB15_E, HB15_O = split_polyphase(HB15)
local HB15_CENTER = HB15[8]  -- Center tap for fast odd phase processing

-- OPTIMIZATION: Shorter half-bands for lower oversampling (much faster!)
local HB11 = { -0.0044, 0, 0.0525, 0, -0.2951, 0.5000, -0.2951, 0, 0.0525, 0, -0.0044 }
local HB9 = { -0.0078, 0, 0.0781, 0, -0.3125, 0.5000, -0.3125, 0, 0.0781, 0, -0.0078 }  -- CORRECTED: Proper 9-tap coefficients
-- For true 9-tap filter, use shorter version:
local HB7 = { -0.0156, 0, 0.1094, 0, -0.3750, 0.5312, -0.3750, 0, 0.1094, 0, -0.0156 }

-- Use HB7 for fastest preview/2x, keep others for quality
local HB11_E, HB11_O = split_polyphase(HB11)  
local HB7_E, HB7_O = split_polyphase(HB7)
local HB11_CENTER = HB11[6]  -- Center of 11-tap filter
local HB7_CENTER = HB7[6]    -- Center of 7-tap filter (but HB7 has 11 elements too!

-- BUGFIX: Let's just use the working HB15/HB11 and a simpler HB7
local HB_FAST = HB11  -- Use HB11 for "fast" mode instead of broken HB9
local HB_FAST_E, HB_FAST_O = HB11_E, HB11_O
local HB_FAST_CENTER = HB11_CENTER

-- OPTIMIZATION: Longest half-band ring buffer length for state management  
local HISTLEN = max(2 * #HB15_E - 1, #HB15_E + 1)  -- Ensure we cover both calculation methods

-- OPTIMIZATION: Clear per-channel state for fresh processing runs
local function clear_state(s)
  -- SAFETY: Ensure arrays exist before clearing
  if s.up_hist then
    for i = 1, #s.up_hist do s.up_hist[i] = 0.0 end
  end
  if s.down_hist then
    for i = 1, #s.down_hist do s.down_hist[i] = 0.0 end
  end
  s.dc_x1, s.dc_y1 = 0.0, 0.0
end

-- Identity function for dry path alignment
local function identity(x) return x end

-- DC blocker function (for asymmetric curves)
local function dc_block_process(buf, R)
  R = R or 0.995
  local x1, y1 = 0.0, 0.0
  for i=1,#buf do
    local x = buf[i]
    local y = x - x1 + R*y1
    buf[i] = y
    x1, y1 = x, y
  end
end

-- OPTIMIZED: Peak detection using localized math function
local function peak_of(buf)
  local m=0; for i=1,#buf do local a=abs(buf[i]); if a>m then m=a end end; return m
end

-- OPTIMIZED: Fast 2x upsampler using half-band tricks + ring buffer
-- Even phase = polyphase MAC, Odd phase = center tap only (half-band property!)
local function up2_poly_fast(xbuf, he, center, hist)
  -- SAFETY: Validate inputs to prevent nil arithmetic errors
  if not xbuf or not he or not center or not hist then
    print("ERROR: up2_poly_fast called with nil parameters")
    return xbuf or {}
  end
  
  local heN = #he
  local required_hist_len = max(2 * heN - 1, heN + 1)
  
  -- SAFETY: Ensure history buffer is large enough (should be pre-allocated now)
  if #hist < required_hist_len then
    -- Silently extend history buffer with zeros (no spam warnings)
    for i = #hist + 1, required_hist_len do
      hist[i] = 0.0
    end
  end
  
  local out, j = {}, 1
  
  -- Ring buffer shift (much faster than table.insert for short filters)
  for n = 1, #xbuf do
    for k = #hist, 2, -1 do hist[k] = hist[k-1] end
    hist[1] = xbuf[n]
    
    -- Even output: MAC only non-zero taps (polyphase)
    local e = 0.0
    for k = 1, heN do 
      local hist_idx = 2*k - 1
      if hist_idx <= #hist and he[k] and hist[hist_idx] then
        e = e + he[k] * hist[hist_idx]
      end
    end
    out[j] = e; j = j + 1
    
    -- Odd output: center tap only (half-band property - saves 6+ multiplies!)
    local center_idx = heN + 1
    if center_idx <= #hist and hist[center_idx] then
      out[j] = center * hist[center_idx]; j = j + 1
    else
      out[j] = 0.0; j = j + 1
    end
  end
  return out
end

-- OPTIMIZED: Fast 2x decimator - compute only on emit, same non-zero taps
local function down2_poly_fast(xbuf, he, center, hist)
  -- SAFETY: Validate inputs to prevent nil arithmetic errors
  if not xbuf or not he or not center or not hist then
    print("ERROR: down2_poly_fast called with nil parameters")
    return xbuf or {}
  end
  
  local heN = #he
  local required_hist_len = max(2 * heN - 1, heN + 1)
  
  -- SAFETY: Ensure history buffer is large enough (should be pre-allocated now)
  if #hist < required_hist_len then
    -- Silently extend history buffer with zeros (no spam warnings)
    for i = #hist + 1, required_hist_len do
      hist[i] = 0.0
    end
  end
  
  local out, j, toggle = {}, 1, 0
  
  for n = 1, #xbuf do
    for k = #hist, 2, -1 do hist[k] = hist[k-1] end
    hist[1] = xbuf[n]
    toggle = 1 - toggle
    
    if toggle == 0 then  -- Emit at half rate only
      local y = 0.0
      local center_idx = heN + 1
      if center_idx <= #hist and hist[center_idx] then
        y = center * hist[center_idx]  -- Center tap
      end
      
      for k = 1, heN do 
        local hist_idx = 2*k - 1
        if hist_idx <= #hist and he[k] and hist[hist_idx] then
          y = y + he[k] * hist[hist_idx]
        end
      end
      out[j] = y; j = j + 1
    end
  end
  return out
end

-- OPTIMIZED: Smart filter selection based on quality needs
local function select_filters(factor, preview)
  if factor <= 2 or preview then 
    return HB_FAST_E, HB_FAST_CENTER, 1  -- Fast HB11 for 2x/preview
  elseif factor <= 4 then 
    return HB11_E, HB11_CENTER, 2  -- Balanced HB11 for 4x
  else 
    return HB15_E, HB15_CENTER, 3  -- Quality HB15 for 8x
  end
end

-- OPTIMIZED: Smart oversampling with ring buffer state and fast polyphase
local function oversample_process(xbuf, factor, nonlinear_fn, is_identity, is_preview, ch_state)
  if factor == 1 then
    if is_identity then return xbuf end  -- FAST: Pure bypass for identity
    local y = {}
    for i = 1, #xbuf do 
      y[i] = nonlinear_fn(xbuf[i]) 
    end
    return y
  end
  
  local he, center, stages = select_filters(factor, is_preview)
  local up_hist, dn_hist = ch_state.up_hist, ch_state.down_hist

  local up = xbuf
  for s = 1, stages do 
    up = up2_poly_fast(up, he, center, up_hist)  -- FAST polyphase!
  end

  if not is_identity then
    -- Apply nonlinearity with fast clamping
    for i = 1, #up do
      local u = up[i]
      u = (u > 1) and 1 or ((u < -1) and -1 or u) -- Branchless clamping
      up[i] = nonlinear_fn(u)
    end
    
    -- OPTIMIZED: DC blocker with continuous state across chunks
    if curve_has_dc() then
      local x1, y1 = ch_state.dc_x1 or 0.0, ch_state.dc_y1 or 0.0
      local R = 0.995
      for i = 1, #up do 
        local x = up[i]
        local y = x - x1 + R * y1
        up[i] = y
        x1, y1 = x, y 
      end
      ch_state.dc_x1, ch_state.dc_y1 = x1, y1  -- Preserve state!
    end
  end

  -- Downsample back with fast polyphase
  for s = 1, stages do 
    up = down2_poly_fast(up, he, center, dn_hist)  -- FAST polyphase!
  end
  
  return up
end



-- Small utilities
local function clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi else return x end end
local function sgn(x) return (x >= 0) and 1 or -1 end

-- Map "Tilt / Tilt Bias" into separate gains for positive/negative lobes.
-- We drive two soft saturators with different input gains (gp/gn) to get asymmetry/even harmonics.
local function magnet_compute_gains(drive, tilt, bias, fb_term)
  -- drive -> exponential feel but tamed
  -- 1.0 => ~x2, 2.0 => ~x4, 3.0 => ~x8 (musical)
  local g_base = 2.0^(drive)   -- pleasant progression
  -- Effective tilt is user tilt + feedback term (program-dependent)
  local t_eff = clamp(tilt + fb_term, -1.0, 1.0)
  -- Split tilt/bias between positive/negative halves.
  -- "bias" pushes asymmetry; "t_eff" skews tone.
  -- Weighting below chosen to feel musical, not explode.
  local sk = 0.85
  local gp = g_base * (1.0 + sk*(t_eff + bias))   -- positive half gain
  local gn = g_base * (1.0 + sk*(-t_eff - bias))  -- negative half gain
  -- Keep both positive and capped
  gp = clamp(gp, 0.1, 16.0)
  gn = clamp(gn, 0.1, 16.0)
  return gp, gn
end

-- Simple, fast soft clip (odd-symmetric core). We'll run it separately on pos/neg branches.
local function softsat(v) -- smooth, tanh-like without heavy math
  -- x / (1 + |x|) has nice tape-ish feel and is cheap
  local a = math.abs(v)
  return v / (1.0 + a)
end

-- Slew limiter: limit |y - y_prev| <= step
local function slew_limit(y_target, y_prev, step)
  local dy = y_target - y_prev
  local a = math.abs(dy)
  if a <= step then return y_target end
  return y_prev + sgn(dy) * step
end

-- Convert user mag_tilt_limit (0..1) -> per-sample max delta in output domain.
-- At 44.1k, ~0.002 ~ gentle; ~0.02 fairly fast; scale a bit with oversampling.
local function map_tilt_limit_to_step(user_amount, os_factor)
  -- user_amount 0..1  -> step 0.001 .. 0.03 (scaled by sqrt(OS) so higher OS feels a bit zippier)
  local base = 0.001 + 0.029 * clamp(user_amount, 0.0, 1.0)
  local scale = math.sqrt(math.max(1, os_factor or 1))
  return base * scale
end

-- Build a per-sample stateful step function (needs a state table to persist y1)
local function make_magnet_step_fn(params)
  local p = {
    drive      = params.drive or mag_drive,
    tilt       = clamp(params.tilt or mag_tilt, -1, 1),
    bias       = clamp(params.bias or mag_tilt_bias, -1, 1),
    tilt_limit = clamp(params.tilt_limit or mag_tilt_limit, 0, 1),
    feedback   = clamp(params.feedback or mag_feedback, 0, 1),
    out        = params.out or mag_out,
    osf        = params.osf or 1
  }

  -- Precompute slew step for current OS
  local slew_step = map_tilt_limit_to_step(p.tilt_limit, p.osf)

  -- Return a function(x, st) -> y, updating st.y1
  local function step(x, st)
    -- Previous output for feedback and slew
    local y1 = st.y1 or 0.0

    -- Feedback term bends tilt towards current program material
    -- (small amount: keep it stable)
    local fb_term = p.feedback * (0.5 * y1)

    -- Compute asym gains for pos/neg halves
    local gp, gn = magnet_compute_gains(p.drive, p.tilt, p.bias, fb_term)

    -- Split input into lobes and run soft clip with different gains
    local xp = (x > 0) and x or 0.0
    local xn = (x < 0) and x or 0.0

    local yp = softsat(gp * xp)
    local yn = softsat(gn * xn)

    -- Recombine (note xn is negative), keep odd core but asym magnitudes
    local y_lin = yp + yn

    -- Slew-limit towards target
    local y = slew_limit(y_lin, y1, slew_step)

    -- Store and post gain
    st.y1 = y
    return clamp(y * p.out, -1.0, 1.0)
  end

  -- Return step function (stateful nature is inherent in the oversample_process_stateful call)
  return step
end

-- ==== Oversampling path that supports stateful per-sample DSP =================
local function oversample_process_stateful(xbuf, factor, step_fn, is_preview, ch_state)
  -- xbuf: input chunk
  -- step_fn(x, st) -> y   (must read/write st.y1)
  -- ch_state: carries up/down filter state + y1 across chunks

  if factor == 1 then
    local out = {}
    local st = ch_state.mag or { y1 = 0.0 }
    for i = 1, #xbuf do
      -- clip input a bit before nonlinearity
      local xi = xbuf[i]
      if xi > 1 then xi = 1 elseif xi < -1 then xi = -1 end
      out[i] = step_fn(xi, st)
    end
    ch_state.mag = st
    return out
  end

  -- Choose filters (reuse your helpers)
  local he, center, stages = select_filters(factor, is_preview)
  local up_hist, dn_hist = ch_state.up_hist, ch_state.down_hist

  -- Upsample
  local up = xbuf
  for s = 1, stages do
    up = up2_poly_fast(up, he, center, up_hist)
  end

  -- Nonlinear per sample with persistent y1
  local st = ch_state.mag or { y1 = 0.0 }
  for i = 1, #up do
    local xi = up[i]
    if xi > 1 then xi = 1 elseif xi < -1 then xi = -1 end
    up[i] = step_fn(xi, st)
  end
  ch_state.mag = st -- persist

  -- Downsample
  for s = 1, stages do
    up = down2_poly_fast(up, he, center, dn_hist)
  end
  return up
end

-- === Build the complete processor ==========================================
local processor_function = nil

local function build_processor()
  -- SMART REBUILD: Skip if parameters haven't actually changed
  local current_hash = param_hash()
  if current_hash == last_param_hash then
    return  -- No change, keep existing processor
  end
  last_param_hash = current_hash
  
  -- EARLY OUT #1: Skip entire pipeline if effect is bypassed
  -- In Chebyshev mode: bypass if wet=0 or all harmonics are zero
  -- In Magnet mode: only bypass if wet=0 (harmonics don't matter)
  local should_bypass = wet_value == 0 or (shaper_mode == "cheby" and is_all_zero(harmonic_gains))
  if should_bypass then
    processor_function = function(inbuf)
      -- Identity processing - just return input (optionally through OS for phase alignment)
      if oversampling_factor == 1 or dry_value == 1 then
        return inbuf  -- Pure bypass - maximum speed!
      else
        -- Phase-align dry through same OS path
        return oversample_process(inbuf, oversampling_factor, identity)
      end
    end
    return
  end
  
  -- AUTO OVERSAMPLING: Choose minimum required based on highest active harmonic
  local actual_os_factor = oversampling_factor
  if oversampling_factor == 0 then  -- Auto mode
    actual_os_factor = choose_auto_oversampling()
  end
  
  -- === NEW: Magnet Shaper mode ==============================================
  if shaper_mode == "magnet" then
    -- Build stateful per-sample stepper with current params
    local stepper = make_magnet_step_fn{
      drive      = mag_drive,
      tilt       = mag_tilt,
      bias       = mag_tilt_bias,
      tilt_limit = mag_tilt_limit,
      feedback   = mag_feedback,
      out        = 1.0,        -- do post trim in mix pass for consistency
      osf        = actual_os_factor
    }

    processor_function = function(inbuf, ch_state)
      ch_state = ch_state or get_state(0, HISTLEN)

      -- Fast dry bypass
      if wet_value == 0 then return inbuf end

      -- Wet path (stateful OS)
      local wetbuf = oversample_process_stateful(inbuf, actual_os_factor, stepper, preview_enabled, ch_state)

      -- Peak protect wet (like you already do)
      local pw = peak_of(wetbuf)
      local wg = (pw > 1e-12) and math.min(1.0, 0.99 / pw) or 1.0
      if wg < 1.0 then
        for i = 1, #wetbuf do wetbuf[i] = wetbuf[i] * wg end
      end

      -- Dry path (phase-align through identity OS if needed)
      local drybuf
      if dry_value > 0 and actual_os_factor > 1 then
        drybuf = oversample_process(inbuf, actual_os_factor, identity, true, preview_enabled, ch_state)
      else
        drybuf = inbuf
      end

      -- Single-pass mix + global output
      local out = {}
      local og, dv, wv = mag_out * output_gain_value, dry_value, wet_value
      for i = 1, #wetbuf do
        local y = dv * drybuf[i] + wv * wetbuf[i]
        if y > 1.0 then y = 1.0 elseif y < -1.0 then y = -1.0 end
        if abs(y) < 1e-20 then y = 0.0 end
        out[i] = y * og
      end

      return out
    end

    return -- done building processor in magnet mode
  end
  
  -- Build coefficients array for Clenshaw evaluation (coeffs[0..13])
  local coeffs = {}
  coeffs[0], coeffs[1] = 0.0, 0.0  -- No DC, no fundamental
  for i = 1, 12 do  -- indices 1-12 map to harmonics 2-13
    coeffs[i + 1] = harmonic_gains[i]
  end
  
  -- OPTIMIZATION: Trim Clenshaw to highest active harmonic for faster LUT build
  local max_harmonic = 0
  for i = 12, 1, -1 do 
    if harmonic_gains[i] ~= 0.0 then 
      max_harmonic = i + 1  -- Convert to harmonic number (H2 = i+1)
      break 
    end 
  end

  local curve_fn = make_precurve(curve_yL, curve_yC, curve_yR)
  local bank_fn = make_series_clenshaw(coeffs, max_harmonic)  -- Trimmed Clenshaw!
  
  -- composite nonlinearity: bank(curve(x))
  local function nl_raw(x) return bank_fn(curve_fn(x)) end
  
  -- OPTIMIZATION: Build LUT and normalize in single pass (eliminates 8-16K probe sweep!)
  local use_lut = true  -- Can be made a user preference later
  local lut_size = preview_enabled and 1024 or 4096  -- Smaller LUT for preview
  local lut, lut_gain = make_lut_normalized(nl_raw, lut_size)
  local processing_fn = make_lut_eval(lut)

  processor_function = function (inbuf, ch_state)
    ch_state = ch_state or {up_hist={}, down_hist={}, dc_x1=0.0, dc_y1=0.0}  -- Fallback
    
    -- FAST PATHS for trivial mixes (huge win!)
    if wet_value == 0 then  -- Pure dry
      return inbuf  -- Identity - can't get faster!
    end
    if wet_value == 1 and dry_value == 0 and output_gain_value == 1 then
      -- Pure wet, no output gain - direct process
      return oversample_process(inbuf, actual_os_factor, processing_fn, false, preview_enabled, ch_state)
    end
    
    -- process wet path with SMART OS
    local wetbuf = oversample_process(inbuf, actual_os_factor, processing_fn, false, preview_enabled, ch_state)
    
    -- Gain staging for wet path to protect mix when Wet is low but shaper explodes
    local pw = peak_of(wetbuf)
    local wg = (pw > 1e-12) and min(1.0, 0.99 / pw) or 1.0
    if wg < 1.0 then 
      for i=1,#wetbuf do wetbuf[i] = wetbuf[i] * wg end 
    end
    
    -- OPTIMIZED: Fix dry/wet combing with fast identity processing
    local drybuf
    if actual_os_factor > 1 and dry_value > 0 then
      drybuf = oversample_process(inbuf, actual_os_factor, nil, true, preview_enabled, ch_state)  -- Identity!
    else
      drybuf = inbuf
    end
    
    -- OPTIMIZED: Single-pass mix + output gain (eliminate extra loop!)
    local out = {}
    local og, dv, wv = output_gain_value, dry_value, wet_value
    for i=1,#wetbuf do
      local y = dv * drybuf[i] + wv * wetbuf[i]
      -- OPTIMIZED: fast clamp + denorm killer using local functions
      if y > 1.0 then y = 1.0 elseif y < -1.0 then y = -1.0 end
      if abs(y) < 1e-20 then y = 0.0 end  -- denorm killer
      out[i] = y * og  -- Apply output gain in same pass!
    end
    
    -- OPTIMIZED: Skip second safety trim when dry_value > 0 (most cases)
    if dry_value == 0 then  -- Only trim when 100% wet
      local p = peak_of(out)
      local pg = (p > 1e-12) and min(1.0, 0.99 / p) or 1.0
      if pg < 1.0 then 
        for i=1,#out do out[i] = out[i] * pg end 
      end
    end
    
    return out
  end
end

-- Initialize processor (with safety check)
local function safe_build_processor()
  -- Ensure all variables are accessible before calling build_processor
  if not shaper_mode then
    print("ERROR: shaper_mode is not defined!")
    shaper_mode = "cheby"
  end
  if not mag_drive then 
    print("ERROR: mag_drive is not defined!")
    mag_drive = 1.0 
  end
  build_processor()
end

safe_build_processor()

-- Debouncing system to prevent excessive rebuilds during parameter changes
local function mark_dirty()
  dirty = true
  last_change_ms = os.clock() * 1000
end

-- Functions declared as global to avoid call-before-definition errors

-- Forward declarations for missing functions
local cache_sample_waveform, generate_processed_waveform_cache, update_canvas_displays
local apply_processing, apply_normalization, restore_sample_range
local toggle_preview, reset_sample, get_edit_range, PakettiChebyshevUpdatePreview

-- Helper functions
get_edit_range = function(buffer)
  local sel = renoise.song().selected_sample and renoise.song().selected_sample.sample_buffer.selection_range
  if sel and sel[1] and sel[2] and sel[1] < sel[2] then
    return sel[1], sel[2]
  end
  return 1, buffer.number_of_frames
end

toggle_preview = function()
  preview_enabled = not preview_enabled
  if vb and vb.views.preview_button then
    vb.views.preview_button.text = preview_enabled and "Disable Preview" or "Enable Preview"
  end
  renoise.app():show_status(preview_enabled and "Preview enabled" or "Preview disabled")
end

reset_sample = function()
  -- BUGFIX: Reset ALL parameters to defaults
  for i = 1, 12 do
    harmonic_gains[i] = 0.0
  end
  curve_yL, curve_yC, curve_yR = -1.0, 0.0, 1.0  -- Identity curve
  dry_value, wet_value = 0.0, 1.0  -- 0% dry, 100% wet (FIXED: better default!)
  output_gain_value = 1.0
  oversampling_factor = 1  -- 1x oversampling
  
  -- Update UI sliders if they exist
  if vb and vb.views then
    if vb.views.curve_yL_slider then vb.views.curve_yL_slider.value = curve_yL end
    if vb.views.curve_yC_slider then vb.views.curve_yC_slider.value = curve_yC end
    if vb.views.curve_yR_slider then vb.views.curve_yR_slider.value = curve_yR end
    if vb.views.dry_slider then vb.views.dry_slider.value = dry_value end
    if vb.views.wet_slider then vb.views.wet_slider.value = wet_value end
    if vb.views.output_slider then vb.views.output_slider.value = output_gain_value end
    if vb.views.curve_yL_value then vb.views.curve_yL_value.text = string.format("%.2f", curve_yL) end
    if vb.views.curve_yC_value then vb.views.curve_yC_value.text = string.format("%.2f", curve_yC) end
    if vb.views.curve_yR_value then vb.views.curve_yR_value.text = string.format("%.2f", curve_yR) end
    if vb.views.dry_value then vb.views.dry_value.text = string.format("%.2f", dry_value) end
    if vb.views.wet_value then vb.views.wet_value.text = string.format("%.2f", wet_value) end
    if vb.views.output_value then vb.views.output_value.text = string.format("%.2f", output_gain_value) end
  end
  
  -- Also restore sample if we have backup
  if backup_sample_data and backup_range then
    restore_sample_range()
  end
  
  build_processor()
  update_canvas_displays()
  if preview_enabled then PakettiChebyshevUpdatePreview() end
  renoise.app():show_status("All parameters reset to defaults")
end

PakettiChebyshevUpdatePreview = function()
  if preview_enabled then
    renoise.app():show_status("Preview updated")
  end
end

-- OPTIMIZATION: Waveform caching with smart invalidation and bulk I/O
local waveform_token = nil

cache_sample_waveform = function()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end
  local buffer = sample.sample_buffer
  local sfrm, efrm = get_edit_range(buffer)
  local token = table.concat({tostring(sample), sfrm, efrm, buffer.number_of_frames, buffer.number_of_channels}, "|")
  
  -- OPTIMIZATION: Skip rebuild if sample/range hasn't changed
  if waveform_token == token and original_waveform_cache then 
    return true 
  end
  waveform_token = token
  
  local num_channels = buffer.number_of_channels
  local samples_to_read = math.min(4096, efrm - sfrm + 1)  -- Limit for UI display
  
  -- OPTIMIZATION: Use HAS_BULK flag to avoid repeated pcalls
  local bulk_data = {}
  if check_bulk_capability() then
    for channel = 1, num_channels do
      bulk_data[channel] = {}
      buffer:copy_channel_data_to_table(channel, sfrm, sfrm + samples_to_read - 1, bulk_data[channel])
    end
  end
  
  -- Build waveform cache
  original_waveform_cache = {}
  for i = 1, samples_to_read do
    local frame_pos = sfrm + i - 1
    local sample_value = 0.0
    
    -- OPTIMIZATION: Branch once on HAS_BULK, not per-sample
    if check_bulk_capability() then
      for channel = 1, num_channels do
        sample_value = sample_value + (bulk_data[channel][i] or 0)
      end
    else
      for channel = 1, num_channels do
        sample_value = sample_value + buffer:sample_data(channel, frame_pos)
      end
    end
    
    original_waveform_cache[i] = sample_value / num_channels  -- Average channels
  end
  
  return true
end

generate_processed_waveform_cache = function()
  if not original_waveform_cache then return false end
  if not processor_function then build_processor() end
  
  -- BUGFIX: Use properly initialized channel state with correct history buffer sizes
  local dummy_state = get_state(0, HISTLEN)  -- Channel 0 for preview
  clear_state(dummy_state)  -- Ensure fresh state
  processed_waveform_cache = processor_function(original_waveform_cache, dummy_state)
  return true
end

update_canvas_displays = function()
  if parameter_canvas then parameter_canvas:update() end
  if waveform_canvas then waveform_canvas:update() end
  if bezier_canvas then bezier_canvas:update() end  -- NEW: Update Bézier canvas
end

apply_processing = function()
  local sample = renoise.song().selected_sample
  if not sample then
    renoise.app():show_status("No sample selected")
    return
  end
  
  -- CORRECT LOGIC: If preview is enabled, the sample is ALREADY processed!
  if preview_enabled then
    -- Just finalize the preview (clear backup, disable preview)
    backup_sample_data = nil
    backup_range = nil
    preview_enabled = false
    if vb and vb.views.preview_button then
      vb.views.preview_button.text = "Enable Preview"
    end
    renoise.app():show_status("Preview finalized - changes are now permanent!")
    return
  end
  
  -- If NO preview, then actually process the sample
  local slicer = ProcessSlicer(apply_chebyshev_waveshaping_process)
  local prog_dialog, prog_vb = slicer:create_dialog("Applying Chebyshev Waveshaper")
  
  -- Update the process function args to include sample, dialog, and vb
  slicer.__process_func_args = {sample, prog_dialog, prog_vb}
  
  -- Start processing
  slicer:start()
end

apply_normalization = function()
  renoise.app():show_status("Normalization not implemented yet")
end

restore_sample_range = function()
  -- Restore from backup if available
  if backup_sample_data and backup_range then
    local sample = renoise.song().selected_sample
    if sample and sample.sample_buffer then
      -- Restore implementation would go here
      renoise.app():show_status("Sample restored from backup")
    end
  end
end

-- OPTIMIZED: Adaptive debounce - longer wait while dragging, shorter when idle
local function idle_tick()
  if not dirty then return end
  local now = now_ms()
  local wait = (now - last_mouse_ms < 50) and 65 or 25  -- 65ms while dragging, 25ms when idle
  if (now - last_change_ms) > wait then
    build_processor()
    -- Always update canvas displays (visual feedback) - this updates the waveform preview
    if cache_sample_waveform() then
      generate_processed_waveform_cache()
    end
    if waveform_canvas then
      waveform_canvas:update()
    end
    -- Only update preview if enabled (affects actual audio)
    if preview_enabled then
      PakettiChebyshevUpdatePreview()
    end
    dirty = false
  end
end

-- Update harmonic value text displays
-- update_harmonic_value_displays removed - labels and values now drawn directly on canvas

-- Preset coefficient patterns
local function apply_preset(preset_name)
  if preset_name == "reset_all" then
    -- Reset all harmonics to zero and curve to identity
    for i = 1, 12 do
      harmonic_gains[i] = 0.0
    end
    curve_yL, curve_yC, curve_yR = -1.0, 0.0, 1.0
    dry_value, wet_value = 0.0, 1.0  -- FIXED: Better default (100% wet)
    output_gain_value = 1.0
  elseif preset_name == "randomize" then
    -- Randomize harmonic gains and curve points for exploration
    for i = 1, 12 do
      harmonic_gains[i] = (math.random() - 0.5) * 1.6  -- -0.8 to +0.8
    end
    curve_yL = -1.0 + math.random() * 0.8  -- -1.0 to -0.2
    curve_yC = (math.random() - 0.5) * 1.0  -- -0.5 to +0.5
    curve_yR = 0.2 + math.random() * 0.8   -- +0.2 to +1.0
    wet_value = 0.3 + math.random() * 0.7  -- ensure some wet signal
  elseif preset_name == "equal" then
    -- Equal amplitude for all harmonics (before normalization)
    for i = 1, 12 do
      harmonic_gains[i] = 0.5  -- Start with moderate level
    end
  elseif preset_name == "rolloff" then
    -- 1/n rolloff pattern (smoother, more musical)
    for i = 1, 12 do
      local harmonic_num = i + 1  -- harmonics 2-13
      harmonic_gains[i] = 0.8 / harmonic_num  -- Scale down for nice levels
    end
  elseif preset_name == "traditional" then
    -- Traditional + - - + + - - pattern (GEN13 style)
    local signs = {1, -1, -1, 1, 1, -1, -1, 1, 1, -1, -1, 1}  -- pattern for harmonics 2-13
    for i = 1, 12 do
      local harmonic_num = i + 1
      harmonic_gains[i] = signs[i] * (0.6 / math.sqrt(harmonic_num))  -- nice scaling
    end
  elseif preset_name == "clear" then
    -- Clear all harmonics
    for i = 1, 12 do
      harmonic_gains[i] = 0.0
    end
  end
  
  -- Update UI sliders to reflect new values
  if vb.views.curve_yL_slider then vb.views.curve_yL_slider.value = curve_yL end
  if vb.views.curve_yC_slider then vb.views.curve_yC_slider.value = curve_yC end
  if vb.views.curve_yR_slider then vb.views.curve_yR_slider.value = curve_yR end
  if vb.views.dry_slider then vb.views.dry_slider.value = dry_value end
  if vb.views.wet_slider then vb.views.wet_slider.value = wet_value end
  if vb.views.output_slider then vb.views.output_slider.value = output_gain_value end
  
  -- Rebuild processor and update display (immediate, not debounced for presets)
  build_processor()
  update_canvas_displays() -- Canvas update will refresh harmonic labels/values
  PakettiChebyshevUpdatePreview()
end

-- Musical macro helpers for quick tone shaping
local function scale_all(k)
  for i = 1, 12 do
    harmonic_gains[i] = harmonic_gains[i] * k
    -- CRITICAL FIX: Clamp to valid slider range [-1.0, 1.0]!
    harmonic_gains[i] = math.max(-1.0, math.min(1.0, harmonic_gains[i]))
  end
end

local function tilt_all(t) -- t in [-1..1]
  for i = 1, 12 do
    local n = i + 1 -- harmonic number (2..13)
    local k = (n - 2) / 11 -- 0..1 across 2..13
    local mult = 2^((t * (0.5 - k)) * 6/20) -- ~±6 dB tilt
    harmonic_gains[i] = harmonic_gains[i] * mult
    -- CRITICAL FIX: Clamp to valid slider range [-1.0, 1.0]!
    harmonic_gains[i] = math.max(-1.0, math.min(1.0, harmonic_gains[i]))
  end
end

local function set_odd_even(odd_gain, even_gain)
  for i = 1, 12 do
    local n = i + 1 -- harmonic number (2..13)
    harmonic_gains[i] = harmonic_gains[i] * ((n % 2 == 1) and odd_gain or even_gain)
    -- CRITICAL FIX: Clamp to valid slider range [-1.0, 1.0]!
    harmonic_gains[i] = math.max(-1.0, math.min(1.0, harmonic_gains[i]))
  end
end

-- Curve presets for different shapes
local function apply_curve_preset(preset_name)
  if preset_name == "linear" then
    -- Linear/identity curve
    curve_yL, curve_yC, curve_yR = -1.0, 0.0, 1.0
  elseif preset_name == "soft" then
    -- Soft center (pull center down for softer knee)
    curve_yL, curve_yC, curve_yR = -1.0, -0.3, 1.0
  elseif preset_name == "hard" then
    -- Hard center (push center up for harder knee)  
    curve_yL, curve_yC, curve_yR = -1.0, 0.3, 1.0
  elseif preset_name == "asym" then
    -- Asymmetric (different left/right for more odd harmonics)
    curve_yL, curve_yC, curve_yR = -1.0, 0.0, 0.8
  end
  
  -- CRITICAL FIX: Update BOTH slider values AND text displays to prevent data loss!
  if vb and vb.views then
    -- Update slider values (CRITICAL - this was missing!)
    if vb.views.curve_yL_slider then vb.views.curve_yL_slider.value = curve_yL end
    if vb.views.curve_yC_slider then vb.views.curve_yC_slider.value = curve_yC end
    if vb.views.curve_yR_slider then vb.views.curve_yR_slider.value = curve_yR end
    
    -- Update text displays
    if vb.views.curve_yL_value then
      vb.views.curve_yL_value.text = string.format("%.2f", curve_yL)
    end
    if vb.views.curve_yC_value then
      vb.views.curve_yC_value.text = string.format("%.2f", curve_yC)
    end
    if vb.views.curve_yR_value then
      vb.views.curve_yR_value.text = string.format("%.2f", curve_yR)
    end
  end
  
  -- Rebuild processor and update display
  build_processor()
  update_canvas_displays()
  PakettiChebyshevUpdatePreview()
end

-- Cache sample waveform data for display
function cache_sample_waveform()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end
  
  local buffer = sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  
  -- Cache original waveform (bulk access for much better performance!)
  original_waveform_cache = {}
  
  -- Use decimation for performance - only read every Nth sample
  local step_size = math.max(1, math.floor(num_frames / waveform_canvas_width))
  local samples_to_read = math.min(waveform_canvas_width * step_size, num_frames)
  
  -- Try bulk reading first (much faster)
  local bulk_data = {}
  local use_bulk = pcall(function()
    for channel = 1, num_channels do
      bulk_data[channel] = {}
      buffer:copy_channel_data_to_table(channel, 1, samples_to_read, bulk_data[channel])
    end
  end)
  
  -- Generate downsampled cache
  for pixel = 1, waveform_canvas_width do
    local frame_pos = math.floor((pixel - 1) * step_size) + 1
    frame_pos = math.max(1, math.min(samples_to_read, frame_pos))
    
    local sample_value = 0
    if use_bulk then
      -- Use bulk data (fast)
      for channel = 1, num_channels do
        sample_value = sample_value + (bulk_data[channel][frame_pos] or 0)
      end
    else
      -- Fallback to frame-by-frame (slower)
    for channel = 1, num_channels do
      sample_value = sample_value + buffer:sample_data(channel, frame_pos)
      end
    end
    sample_value = sample_value / num_channels
    
    original_waveform_cache[pixel] = sample_value
  end
  
  return true
end

-- Generate processed waveform cache using the new processor
function generate_processed_waveform_cache()
  if not original_waveform_cache then
    return false
  end
  
  -- Build processor if not available (fixes nil error on dialog open)
  if not processor_function then
    build_processor()
  end
  
  -- Use the processor function for consistent preview
  if processor_function then
    local output = processor_function(original_waveform_cache)
    processed_waveform_cache = output
    return true
  end
  
  return false
end

-- Render parameter canvas
function render_parameter_canvas(ctx)
  local w, h = parameter_canvas_width, parameter_canvas_height
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background with subtle gradient
  ctx:set_fill_linear_gradient(0, 0, 0, h)
  ctx:add_fill_color_stop(0, {35, 35, 35, 255})
  ctx:add_fill_color_stop(1, {15, 15, 15, 255})
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:fill()
  
  -- Draw 12 vertical harmonic sliders (harmonics 2-13)
  local slider_width = 64  -- INCREASED: Use full canvas width (780px total: 12×64 + 11×1 = 779px)
  local slider_gap = 1  -- ULTRA-MINIMAL spacing between sliders (1px) - pack them tight!
  local total_slider_width = 12 * slider_width + 11 * slider_gap  -- All sliders + gaps between
  local start_x = (w - total_slider_width) / 2  -- Center the slider group
  local slider_height = h - 60  -- Leave room for labels
  local slider_top = 30
  local center_y = slider_top + slider_height / 2  -- Zero point for -1.0 to 1.0 range
  
  for i = 1, 12 do  -- indices 1-12 for harmonics 2-13
    local harmonic_num = i + 1  -- actual harmonic number (2, 3, 4, ..., 13)
    local x = start_x + (i - 1) * (slider_width + slider_gap)  -- FIXED: Use new spacing variables
    local gain = harmonic_gains[i]  -- -1.0 to 1.0
    
    -- Calculate handle position (0.0 is center, -1.0 is bottom, +1.0 is top)
    local handle_y = center_y - (gain * (slider_height / 2))
    
    -- OPTIMIZED: Use precomputed colors (no trigonometry during render!)
    local r, g, b = SLIDER_COLORS[i][1], SLIDER_COLORS[i][2], SLIDER_COLORS[i][3]
    
    -- Helper function to ensure valid color values (0-255 integers)
    local function clamp_color(val)
      return math.max(0, math.min(255, math.floor(val)))
    end
    
    -- Draw slider track (recessed look)
    ctx:set_fill_linear_gradient(x, slider_top, x + slider_width, slider_top)
    ctx:add_fill_color_stop(0, {clamp_color(r * 0.3), clamp_color(g * 0.3), clamp_color(b * 0.3), 255})
    ctx:add_fill_color_stop(0.5, {clamp_color(r * 0.15), clamp_color(g * 0.15), clamp_color(b * 0.15), 255})
    ctx:add_fill_color_stop(1, {clamp_color(r * 0.3), clamp_color(g * 0.3), clamp_color(b * 0.3), 255})
  ctx:begin_path()
    ctx:rect(x, slider_top, slider_width, slider_height)
  ctx:fill()
  
    -- Draw center line (zero position)
    ctx.stroke_color = {100, 100, 100, 180}
    ctx.line_width = 1
  ctx:begin_path()
    ctx:move_to(x + 2, center_y)
    ctx:line_to(x + slider_width - 2, center_y)
    ctx:stroke()
    
    -- Draw slider handle with 3D effect
    local handle_height = 12
    if gain ~= 0.0 then  -- Only draw handle if gain is not zero
      ctx:set_fill_linear_gradient(x, handle_y - handle_height/2, x + slider_width, handle_y - handle_height/2)
      ctx:add_fill_color_stop(0, {clamp_color(r * 1.4), clamp_color(g * 1.4), clamp_color(b * 1.4), 255})
      ctx:add_fill_color_stop(0.3, {clamp_color(r), clamp_color(g), clamp_color(b), 255})
      ctx:add_fill_color_stop(0.7, {clamp_color(r * 0.8), clamp_color(g * 0.8), clamp_color(b * 0.8), 255})
      ctx:add_fill_color_stop(1, {clamp_color(r * 0.6), clamp_color(g * 0.6), clamp_color(b * 0.6), 255})
  ctx:begin_path()
      ctx:rect(x + 1, handle_y - handle_height/2, slider_width - 2, handle_height)
  ctx:fill()
  
      -- Handle highlight
      ctx:set_fill_linear_gradient(x + 2, handle_y - 3, x + 2, handle_y + 1)
      ctx:add_fill_color_stop(0, {255, 255, 255, 100})
      ctx:add_fill_color_stop(1, {255, 255, 255, 30})
  ctx:begin_path()
      ctx:rect(x + 2, handle_y - 3, slider_width - 4, 4)
  ctx:fill()
    end
    
    -- Draw harmonic label above slider using canvas font (THICKER font for better readability)
    ctx.stroke_color = {200, 200, 200, 255}
    ctx.line_width = 2  -- Made font 2x thicker for better readability
    local label = "H" .. tostring(harmonic_num)
    local label_size = 8
    local label_width = label_size * #label * 1.6  -- Matches new font spacing for proper centering
    local label_x = x + (slider_width - label_width) / 2
    PakettiCanvasFontDrawText(ctx, label, label_x, slider_top - 20, label_size)
    
    -- Draw value below slider using canvas font (THICKER font for better readability)
    ctx.stroke_color = {180, 180, 180, 255}
    ctx.line_width = 2  -- Made font 2x thicker for better readability
    local value_text = string.format("%.2f", gain)
    local value_size = 6
    local value_width = value_size * #value_text * 1.6  -- Matches new font spacing for proper centering
    local value_x = x + (slider_width - value_width) / 2
    PakettiCanvasFontDrawText(ctx, value_text, value_x, slider_top + slider_height + 8, value_size)
  end
end

-- NEW: Render Bézier curve visualization
function render_bezier_canvas(ctx)
  local w, h = 200, 120  -- Updated canvas size
  ctx:clear_rect(0, 0, w, h)
  
  -- Background
  ctx.fill_color = {30, 30, 30}
  ctx:fill_rect(0, 0, w, h)
  
  -- Grid lines
  ctx.line_width = 1
  ctx.stroke_color = {60, 60, 60}
  
  -- Vertical center line (x=0)
  local center_x = w * 0.5
  ctx:begin_path()
  ctx:move_to(center_x, 0)
  ctx:line_to(center_x, h)
  ctx:stroke()
  
  -- Horizontal center line (y=0) 
  local center_y = h * 0.5
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(w, center_y)
  ctx:stroke()
  
  -- Draw Bézier curve using proper quadratic Bézier curve drawing
  ctx.line_width = 2
  ctx.stroke_color = {255, 180, 0}  -- Orange curve
  
  -- Map control points to canvas coordinates
  local left_canvas_x = 0
  local left_canvas_y = center_y - (curve_yL * center_y)
  
  local center_canvas_x = center_x
  local center_canvas_y = center_y - (curve_yC * center_y)
  
  local right_canvas_x = w - 1
  local right_canvas_y = center_y - (curve_yR * center_y)
  
  -- Draw left half: Bézier from left to center
  ctx:begin_path()
  ctx:move_to(left_canvas_x, left_canvas_y)
  
  -- Control point for left half is midpoint between left and center
  local left_ctrl_x = (left_canvas_x + center_canvas_x) * 0.5
  local left_ctrl_y = (curve_yL + curve_yC) * 0.5
  left_ctrl_y = center_y - (left_ctrl_y * center_y)
  
  ctx:quadratic_curve_to(left_ctrl_x, left_ctrl_y, center_canvas_x, center_canvas_y)
  ctx:stroke()
  
  -- Draw right half: Bézier from center to right
  ctx:begin_path()
  ctx:move_to(center_canvas_x, center_canvas_y)
  
  -- Control point for right half is midpoint between center and right  
  local right_ctrl_x = (center_canvas_x + right_canvas_x) * 0.5
  local right_ctrl_y = (curve_yC + curve_yR) * 0.5
  right_ctrl_y = center_y - (right_ctrl_y * center_y)
  
  ctx:quadratic_curve_to(right_ctrl_x, right_ctrl_y, right_canvas_x, right_canvas_y)
  ctx:stroke()
  
  -- Draw control points as rectangles (fill_oval might not work)
  -- Left point (-1, yL)
  local left_x = 0
  local left_y = center_y - (curve_yL * center_y)
  ctx.fill_color = {255, 100, 100}  -- Red
  ctx:fill_rect(left_x - 3, left_y - 3, 6, 6)
  
  -- Center point (0, yC)
  local center_point_x = center_x  
  local center_point_y = center_y - (curve_yC * center_y)
  ctx.fill_color = {100, 255, 100}  -- Green
  ctx:fill_rect(center_point_x - 3, center_point_y - 3, 6, 6)
  
  -- Right point (+1, yR)
  local right_x = w - 1
  local right_y = center_y - (curve_yR * center_y)
  ctx.fill_color = {100, 100, 255}  -- Blue
  ctx:fill_rect(right_x - 3, right_y - 3, 6, 6)
  
  -- Simple text labels (avoid PakettiCanvasFont dependency for now)
  ctx.line_width = 1
  ctx.stroke_color = {180, 180, 180}
  -- Just draw simple lines for L, C, R markers
  -- L marker
  ctx:begin_path()
  ctx:move_to(5, 15)
  ctx:line_to(5, 25)
  ctx:line_to(12, 25)
  ctx:stroke()
  
  -- C marker  
  ctx:begin_path()
  ctx:move_to(center_x - 5, 15)
  ctx:line_to(center_x - 5, 25)
  ctx:move_to(center_x - 5, 15)
  ctx:line_to(center_x + 2, 15)
  ctx:move_to(center_x - 5, 25)
  ctx:line_to(center_x + 2, 25)
  ctx:stroke()
  
  -- R marker
  ctx:begin_path()
  ctx:move_to(w - 12, 15)
  ctx:line_to(w - 12, 25)
  ctx:line_to(w - 7, 15)
  ctx:line_to(w - 5, 20)
  ctx:line_to(w - 12, 20)
  ctx:stroke()
end

-- Render waveform canvas
local function render_waveform_canvas(ctx)
  local w, h = waveform_canvas_width, waveform_canvas_height
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background
  ctx.fill_color = {15, 15, 15, 255}
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:fill()
  
  -- Draw grid
  ctx.stroke_color = {40, 40, 40, 255}
  ctx.line_width = 1
  for i = 0, 10 do
    local x = (i / 10) * w
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  for i = 0, 8 do
    local y = (i / 8) * h
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end
  
  -- Draw center line (zero)
  ctx.stroke_color = {100, 100, 100, 255}
  ctx.line_width = 1
  local center_y = h / 2
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(w, center_y)
  ctx:stroke()
  
  -- Draw original waveform (if cached)
  if original_waveform_cache then
    ctx.stroke_color = {100, 150, 255, 180}
    ctx.line_width = 1
    ctx:begin_path()
    
    for pixel = 1, #original_waveform_cache do
      local x = (pixel - 1) / (#original_waveform_cache - 1) * w
      local y = center_y - (original_waveform_cache[pixel] * center_y)
      
      if pixel == 1 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
    ctx:stroke()
  end
  
  -- Draw processed waveform (if cached)
  if processed_waveform_cache then
    ctx.stroke_color = {255, 150, 100, 255}
    ctx.line_width = 2
    ctx:begin_path()
    
    for pixel = 1, #processed_waveform_cache do
      local x = (pixel - 1) / (#processed_waveform_cache - 1) * w
      local y = center_y - (processed_waveform_cache[pixel] * center_y)
      
      if pixel == 1 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
    ctx:stroke()
  end
end

-- Update canvas displays
function update_canvas_displays()
  if cache_sample_waveform() then
    generate_processed_waveform_cache()
  end
  
  if parameter_canvas then
    parameter_canvas:update()
  end
  if waveform_canvas then
    waveform_canvas:update()
  end
end

-- Handle mouse events on parameter canvas
function handle_parameter_canvas_mouse(ev)
  local w, h = parameter_canvas_width, parameter_canvas_height
  local slider_width = 64  -- INCREASED: Match the render function - use full canvas width
  local slider_gap = 1  -- ULTRA-MINIMAL spacing between sliders (1px) - pack them tight! - MATCH render function
  local total_slider_width = 12 * slider_width + 11 * slider_gap  -- All sliders + gaps between
  local start_x = (w - total_slider_width) / 2  -- Center the slider group - MATCH render function
  local slider_height = h - 60  -- Match render function
  local slider_top = 30
  local center_y = slider_top + slider_height / 2
  
  -- Check if mouse is within canvas bounds
  local mouse_x = ev.position.x
  local mouse_y = ev.position.y
  local mouse_in_bounds = mouse_x >= 0 and mouse_x <= w and mouse_y >= 0 and mouse_y <= h
  
  if ev.type == "down" and ev.button == "left" and mouse_in_bounds then
    -- Manual double-click detection
    local current_time = os.clock() * 1000  -- Convert to milliseconds
    local time_diff = current_time - last_click_time
    local distance = math.sqrt((mouse_x - last_click_x)^2 + (mouse_y - last_click_y)^2)
    
    local is_double_click = (time_diff < double_click_threshold) and (distance < 10)
    
    -- Find which harmonic slider was clicked (indices 1-12 for harmonics 2-13)
    local clicked_index = nil
    for i = 1, 12 do
      local x = start_x + (i - 1) * (slider_width + slider_gap)  -- FIXED: Use new spacing variables
      if mouse_x >= x and mouse_x <= x + slider_width and 
         mouse_y >= slider_top and mouse_y <= slider_top + slider_height then
        clicked_index = i
        break
      end
    end
    
    if clicked_index then
      -- Gesture modifier detection
      local ctrl = ev.modifiers and ev.modifiers:find("control")
      local shift = ev.modifiers and ev.modifiers:find("shift")
      local alt = ev.modifiers and ev.modifiers:find("alt")
      
      -- Ctrl-click: reset to 0.0
      if ctrl then
        harmonic_gains[clicked_index] = 0.0
        -- Values now updated directly on canvas
        if parameter_canvas then parameter_canvas:update() end
        mark_dirty()
        return
      end
      
      if is_double_click then
        -- Double-click: reset harmonic to 0.0
        harmonic_gains[clicked_index] = 0.0
        -- Values now updated directly on canvas
        if parameter_canvas then parameter_canvas:update() end
        mark_dirty()
        -- Reset click tracking
        last_click_time = 0
        return -- Don't start dragging on double-click
      else
        -- Single click: start dragging
        drag_param_type = "harmonic_index" .. clicked_index
      is_dragging_param = true
      
        -- Calculate gain value from Y position (-1.0 to 1.0, center is 0.0)
        local y_offset = mouse_y - center_y
        local gain = -y_offset / (slider_height / 2)  -- Invert Y (top = +1, bottom = -1)
        
        -- Shift-drag: fine control (0.25x sensitivity)
        if shift then
          local sens = 0.25
          gain = gain * sens + (1 - sens) * harmonic_gains[clicked_index]
        end
        
        gain = math.max(-1.0, math.min(1.0, gain))
        
        harmonic_gains[clicked_index] = gain
        -- Values now updated directly on canvas
        if parameter_canvas then parameter_canvas:update() end
        mark_dirty()
      end
    end
    
    -- Update click tracking for next time
    last_click_time = current_time
    last_click_x = mouse_x
    last_click_y = mouse_y
    
  elseif ev.type == "move" then
    -- Only continue if we're dragging
    if is_dragging_param then
      -- NEW: TASK 2 - Drag-across painting! Find which slider we're currently over
      local current_index = nil
      for i = 1, 12 do
        local x = start_x + (i - 1) * (slider_width + slider_gap)  -- FIXED: Use new spacing variables
        if mouse_x >= x and mouse_x <= x + slider_width and 
           mouse_y >= slider_top and mouse_y <= slider_top + slider_height then
          current_index = i
          break
        end
      end
      
      -- If we're over a valid slider, update its value
      if current_index then
        -- Gesture modifier detection for move
        local shift = ev.modifiers and ev.modifiers:find("shift")
        local alt = ev.modifiers and ev.modifiers:find("alt")
        
        -- Calculate gain value from Y position
        local y_offset = mouse_y - center_y
        local gain = -y_offset / (slider_height / 2)  -- Invert Y
        
        -- Shift-drag: fine control (0.25x sensitivity)
        if shift then
          local sens = 0.25
          gain = gain * sens + (1 - sens) * harmonic_gains[current_index]
        end
        
        gain = math.max(-1.0, math.min(1.0, gain))
        
        -- NEW: Paint the current slider we're dragging over!
        harmonic_gains[current_index] = gain
        
        -- Alt-drag: paint same value to neighboring harmonics
        if alt then
          -- Apply to immediate neighbors
          if current_index > 1 then harmonic_gains[current_index - 1] = gain end
          if current_index < 12 then harmonic_gains[current_index + 1] = gain end
        end
      
        -- Values now updated directly on canvas
        if parameter_canvas then parameter_canvas:update() end
        mark_dirty()
      end
    end
    
  elseif ev.type == "up" and ev.button == "left" then
    -- Always reset drag state on mouse up, regardless of position
    is_dragging_param = false
    drag_param_type = nil
  end
end

-- Apply Chebyshev waveshaping to sample
-- Get edit range (selection or whole sample)
local function get_edit_range(buffer)
  local sel = renoise.song().selected_sample and renoise.song().selected_sample.sample_buffer.selection_range
  if sel and sel[1] and sel[2] and sel[1] < sel[2] then
    return sel[1], sel[2]
  end
  return 1, buffer.number_of_frames
end

-- ProcessSlicer coroutine for Chebyshev waveshaping
local function apply_chebyshev_waveshaping_process(sample, dialog, vb)
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end

  local buffer = sample.sample_buffer
  local num_channels = buffer.number_of_channels

  -- Get edit range (selection or whole sample)
  local start_frame, end_frame = get_edit_range(buffer)
  local total_frames = end_frame - start_frame + 1

  -- Wrap in proper undo block
  renoise.song():describe_undo("Chebyshev Waveshaper")
  buffer:prepare_sample_data_changes()

  -- OPTIMIZED: Use adaptive chunk sizing for optimal performance
  local chunk_size = math.min(get_optimal_chunk_size(oversampling_factor), total_frames)
  local chunks = math.ceil(total_frames / chunk_size)
  
  -- Only show simple progress: 0% → 50% → 100% (not constant counting!)
  local progress_updates = {25, 50, 75}
  local next_progress_idx = 1

  for channel = 1, num_channels do
    -- Get per-channel state and clear for fresh processing run
    local ch_state = get_state(channel, HISTLEN)
    clear_state(ch_state)  -- Fresh filter/DC state for new run
    
    for chunk = 1, chunks do
      -- Calculate chunk boundaries 
      local chunk_start = start_frame + (chunk - 1) * chunk_size
      local chunk_end = math.min(chunk_start + chunk_size - 1, end_frame)
      
      -- OPTIMIZED: Fast bulk read using our new read_chunk
      local N = read_chunk(INBUF, buffer, channel, chunk_start, chunk_end)
      
      -- SAFETY: Ensure processor exists
      if not processor_function then
        build_processor()  -- Rebuild if missing
      end
      
      -- Process chunk through the processor with continuous channel state
      local outbuf = processor_function(INBUF, ch_state)
      
      -- OPTIMIZED: Reuse OUTBUF to avoid allocations
      for i = 1, N do OUTBUF[i] = outbuf[i] end
      for i = N + 1, #OUTBUF do OUTBUF[i] = nil end  -- Trim to exact size
      
      -- OPTIMIZED: Fast bulk write using our new write_chunk
      write_chunk(OUTBUF, buffer, channel, chunk_start)
      
      -- Smart progress updates: only at key milestones, not constant counting
      local overall_progress = math.floor((((channel - 1) * chunks + chunk) / (num_channels * chunks)) * 100)
      if next_progress_idx <= #progress_updates and overall_progress >= progress_updates[next_progress_idx] then
        if vb and vb.views.progress_text then
          local mode_name = shaper_mode == "magnet" and "Magnet" or "Chebyshev"
          vb.views.progress_text.text = string.format("Processing %s (%dx)... %d%%", 
            mode_name,
            (oversampling_factor == 0 and choose_auto_oversampling() or oversampling_factor),
            progress_updates[next_progress_idx])
        end
        next_progress_idx = next_progress_idx + 1
        
        -- Yield only at progress milestones (much less frequent!)
        coroutine.yield()
      end
    end
  end

  buffer:finalize_sample_data_changes()
  
  -- Close progress dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  return true
end

-- Main apply function using ProcessSlicer
local function apply_chebyshev_waveshaping(sample)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Create progress dialog first
  local slicer = ProcessSlicer(apply_chebyshev_waveshaping_process)
  local prog_dialog, prog_vb = slicer:create_dialog("Applying Chebyshev Waveshaper")
  
  -- Update the process function args to include sample, dialog, and vb
  slicer.__process_func_args = {sample, prog_dialog, prog_vb}
  
  -- Start processing
  slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  
  return true
end

-- Backup current sample data for preview mode (selection-aware)
local function backup_sample_range()
  local s = renoise.song().selected_sample
  if not (s and s.sample_buffer and s.sample_buffer.has_sample_data) then return false end
  
  local buf = s.sample_buffer
  local sfrm, efrm = get_edit_range(buf)
  backup_range = {sfrm, efrm}
  backup_sample_data = {}
  
  for ch = 1, buf.number_of_channels do
    local v = {}
    -- Try bulk copy first (much faster than frame by frame)
    local success = pcall(function()
      buf:copy_channel_data_to_table(ch, sfrm, efrm, v)
    end)
    
    -- Fallback to frame-by-frame if bulk copy fails
    if not success then
      for f = sfrm, efrm do 
        v[#v + 1] = buf:sample_data(ch, f) 
      end
    end
    
    backup_sample_data[ch] = v
  end
  
  return true
end

-- Restore sample data from backup (selection-aware)
local function restore_sample_range()
  if not backup_sample_data or not backup_range then return false end
  
  local s = renoise.song().selected_sample
  if not (s and s.sample_buffer and s.sample_buffer.has_sample_data) then return false end
  
  local buf = s.sample_buffer
  local sfrm, efrm = backup_range[1], backup_range[2]
  buf:prepare_sample_data_changes()
  
  for ch = 1, #backup_sample_data do
    local v = backup_sample_data[ch]
    -- Try bulk copy first (much faster than frame by frame)
    local success = pcall(function()
      buf:copy_channel_data_from_table(ch, sfrm, v)
    end)
    
    -- Fallback to frame-by-frame if bulk copy fails
    if not success then
      for i = 1, #v do 
        buf:set_sample_data(ch, sfrm + i - 1, v[i]) 
      end
    end
  end
  
  buf:finalize_sample_data_changes()
  return true
end

-- Apply normalization using the existing Paketti function
local function apply_normalization()
  -- Use the existing NormalizeSelectedSliceInSample function from PakettiProcess.lua
  if NormalizeSelectedSliceInSample then
    NormalizeSelectedSliceInSample()
  else
    renoise.app():show_status("Normalization function not available")
  end
end

-- Update preview
function PakettiChebyshevUpdatePreview()
  if not preview_enabled then return end
  
  -- Restore original sample first
  restore_sample_range()
  
  -- Apply current settings
  local sample = renoise.song().selected_sample
  if apply_chebyshev_waveshaping(sample) then
    -- Apply auto-normalize in preview if enabled
    if auto_normalize_enabled then
      apply_normalization()
    end
  end
  
  -- Note: canvas displays are updated separately by idle_tick to avoid loops
end

-- Apply final processing
local function apply_processing()
  if preview_enabled then
    -- Disable preview mode first
    preview_enabled = false
    restore_sample_range()
  end
  
  -- Apply the effect
  local sample = renoise.song().selected_sample
  if apply_chebyshev_waveshaping(sample) then
    -- Apply auto-normalize if enabled
    if auto_normalize_enabled then
      apply_normalization()
    end
    
    -- Count active harmonics for status message
    local active_harmonics = 0
    for i = 1, 12 do  -- indices 1-12 for harmonics 2-13
      if harmonic_gains[i] ~= 0.0 then
        active_harmonics = active_harmonics + 1
      end
    end
    
    renoise.app():show_status(string.format("Applied Chebyshev multi-harmonic waveshaping (%d harmonics active)%s", 
      active_harmonics, auto_normalize_enabled and " + normalized" or ""))
  else
    renoise.app():show_error("Failed to apply Chebyshev waveshaping")
  end
end

-- Reset to original sample
local function reset_sample()
  if backup_sample_data then
    restore_sample_range()
    preview_enabled = false
    renoise.app():show_status("Reset to original sample")
  end
end

-- Toggle preview mode
local function toggle_preview()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected")
    return
  end
  
  if preview_enabled then
    -- Disable preview
    preview_enabled = false
    restore_sample_range()
    renoise.app():show_status("Preview disabled")
  else
    -- Enable preview
    if backup_sample_range() then
      preview_enabled = true
      PakettiChebyshevUpdatePreview()
      renoise.app():show_status("Preview enabled - changes are temporary")
    else
      renoise.app():show_error("Failed to backup sample for preview")
    end
  end
  
  -- Update button text
  if vb and vb.views and vb.views.preview_button then
    vb.views.preview_button.text = preview_enabled and "Disable Preview" or "Enable Preview"
  end
end

-- Key handler function
local function my_keyhandler_func(dialog, key)
  local closer = "esc"
  if preferences and preferences.pakettiDialogClose then
    closer = preferences.pakettiDialogClose.value
  end
  
  if key.modifiers == "" and key.name == closer then
    print("DEBUG: Chebyshev Waveshaper - Close key pressed:", key.name)
    
    -- Reset dragging state only when closing
    if is_dragging_param then
      is_dragging_param = false
      drag_param_type = nil
    end
    
    -- Clean up preview mode if active
    if preview_enabled then
      preview_enabled = false
      restore_sample_range()
      print("DEBUG: Chebyshev Waveshaper - Cleaned up preview mode")
    end
    
    -- Clear backup data
    backup_sample_data = nil
    
    dialog:close()
    return nil
  else
    return key
  end
end

-- Show Chebyshev Waveshaper dialog
function show_chebyshev_waveshaper()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected")
    return
  end

  -- Close existing dialog if open
  if dialog and dialog.visible then
    dialog:close()
  end

  -- RESET ALL STATE when dialog reopens (fix persistent preview issue!)
  preview_enabled = false
  backup_sample_data = nil
  backup_range = nil
  dirty = false
  last_change_ms = 0
  
  -- Reset processing state
  processor_function = nil
  original_waveform_cache = nil
  processed_waveform_cache = nil

  -- Create fresh ViewBuilder
  vb = renoise.ViewBuilder()

  local content = vb:column{
    
    
    -- Shaper Mode Selection
    vb:column{
      style = "group",
      width = 780,
      
      vb:text{
        text = "Waveshaper Mode:",
        font = "bold"
      },
      
      vb:row{
        vb:switch{
          id = "shaper_mode_switch",
          items = {"Chebyshev", "Magnet"},
          value = shaper_mode == "magnet" and 2 or 1,
          width = 200,
          notifier = function(idx)
            shaper_mode = (idx == 2) and "magnet" or "cheby"
            -- Show/hide relevant UI sections
            if vb.views.cheby_section then
              vb.views.cheby_section.visible = (shaper_mode == "cheby")
            end
            if vb.views.magnet_section then
              vb.views.magnet_section.visible = (shaper_mode == "magnet")
            end
            mark_dirty()
            renoise.app():show_status("Switched to " .. (shaper_mode == "magnet" and "Magnet" or "Chebyshev") .. " mode")
          end
        },
        
        vb:text{
          text = shaper_mode == "magnet" and "Asymmetric soft-saturation with program-dependent feedback" or "Polynomial harmonic distortion with precise overtone control",
          style = "disabled"
        },
        
        vb:row{
          vb:text{text = "Oversampling:", font = "bold"},
          vb:switch{
            items = {"Auto", "1x", "2x", "4x"},
            value = (function(f) for i,v in ipairs(OS_VALUES) do if v==f then return i end end return 1 end)(oversampling_factor),
            width = 200,
            notifier = function(idx)
              oversampling_factor = OS_VALUES[math.max(1, math.min(#OS_VALUES, idx))] or 1
              mark_dirty()
            end
          }
        }
      }
    },
    
    -- Magnet Shaper Controls (only visible in magnet mode)
    vb:column{
      id = "magnet_section",
      style = "group",
      width = 780,
      visible = shaper_mode == "magnet",
      
      vb:text{
        text = "Magnet Shaper Parameters:",
        font = "bold"
      },
      
      vb:row{
        -- Drive and Tilt
        vb:column{
          vb:row{
            vb:text{text = "Drive:", width = 50},
            vb:slider{
              id = "mag_drive_slider",
              min = 0.1, max = 3.0, value = mag_drive, width = 100,
              notifier = function(value)
                mag_drive = value
                if vb.views.mag_drive_value then
                  vb.views.mag_drive_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_drive_value", text = string.format("%.2f", mag_drive), width = 35}
          },
          
          vb:row{
            vb:text{text = "Tilt:", width = 50},
            vb:slider{
              id = "mag_tilt_slider",
              min = -1.0, max = 1.0, value = mag_tilt, width = 100,
              notifier = function(value)
                mag_tilt = value
                if vb.views.mag_tilt_value then
                  vb.views.mag_tilt_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_tilt_value", text = string.format("%.2f", mag_tilt), width = 35}
          }
        },
        
        -- Bias and Limit
        vb:column{
          vb:row{
            vb:text{text = "Bias:", width = 50},
            vb:slider{
              id = "mag_bias_slider",
              min = -1.0, max = 1.0, value = mag_tilt_bias, width = 100,
              notifier = function(value)
                mag_tilt_bias = value
                if vb.views.mag_bias_value then
                  vb.views.mag_bias_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_bias_value", text = string.format("%.2f", mag_tilt_bias), width = 35}
          },
          
          vb:row{
            vb:text{text = "Limit:", width = 50},
            vb:slider{
              id = "mag_limit_slider",
              min = 0.0, max = 1.0, value = mag_tilt_limit, width = 100,
              notifier = function(value)
                mag_tilt_limit = value
                if vb.views.mag_limit_value then
                  vb.views.mag_limit_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_limit_value", text = string.format("%.2f", mag_tilt_limit), width = 35}
          }
        },
        
        -- Feedback and Output
        vb:column{
          vb:row{
            vb:text{text = "Feedback:", width = 60},
            vb:slider{
              id = "mag_feedback_slider",
              min = 0.0, max = 1.0, value = mag_feedback, width = 100,
              notifier = function(value)
                mag_feedback = value
                if vb.views.mag_feedback_value then
                  vb.views.mag_feedback_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_feedback_value", text = string.format("%.2f", mag_feedback), width = 35}
          },
          
          vb:row{
            vb:text{text = "Out:", width = 60},
            vb:slider{
              id = "mag_out_slider",
              min = 0.1, max = 2.0, value = mag_out, width = 100,
              notifier = function(value)
                mag_out = value
                if vb.views.mag_out_value then
                  vb.views.mag_out_value.text = string.format("%.2f", value)
                end
                mark_dirty()
              end
            },
            vb:text{id = "mag_out_value", text = string.format("%.2f", mag_out), width = 35}
          }
        }
      }
    },
    
    -- Global Controls
    vb:column{
      id = "cheby_section",
      style = "group",
      width = 780,
      visible = shaper_mode == "cheby",
      
      -- Curve Controls
      vb:row{
        vb:column{
      vb:text{
            text = "Input Curve (Pre-Shaping):",
        font = "bold"
      },      
      vb:row{
        -- LEFT SIDE: Curve controls
        vb:column{          
              -- Left point (yL)
            vb:row{
                vb:text{
                  text = "Left (-1)",
                  width = 60
                },
                vb:slider{
                  id = "curve_yL_slider",
                  min = -1.0,
                  max = 1.0,
                  value = curve_yL,
                  width = 80,
                  notifier = function(value)
                    last_mouse_ms = now_ms()  -- Track mouse activity for adaptive debounce
                    curve_yL = value
                    if vb.views.curve_yL_value then
                      vb.views.curve_yL_value.text = string.format("%.2f", value)
                    end
                    if bezier_canvas then bezier_canvas:update() end  -- NEW: Update Bézier canvas
                    mark_dirty()
                  end
                },
                vb:text{
                  id = "curve_yL_value",
                  text = string.format("%.2f", curve_yL),
                  width = 35
                }
              },
              
              -- Center point (yC)
            vb:row{
                vb:text{
                  text = "Center (0)",
                  width = 60
                },
                vb:slider{
                  id = "curve_yC_slider",
                  min = -1.0,
                  max = 1.0,
                  value = curve_yC,
                  width = 80,
                  notifier = function(value)
                    curve_yC = value
                    if vb.views.curve_yC_value then
                      vb.views.curve_yC_value.text = string.format("%.2f", value)
                    end
                    if bezier_canvas then bezier_canvas:update() end  -- NEW: Update Bézier canvas
                    mark_dirty()
                  end
                },
                vb:text{
                  id = "curve_yC_value",
                  text = string.format("%.2f", curve_yC),
                  width = 35
                }
              },
              
              -- Right point (yR)
            vb:row{
                vb:text{
                  text = "Right (+1)",
                  width = 60
                },
                vb:slider{
                  id = "curve_yR_slider",
                  min = -1.0,
                  max = 1.0,
                  value = curve_yR,
                  width = 80,
                  notifier = function(value)
                    curve_yR = value
                    if vb.views.curve_yR_value then
                      vb.views.curve_yR_value.text = string.format("%.2f", value)
                    end
                    if bezier_canvas then bezier_canvas:update() end  -- NEW: Update Bézier canvas
                    mark_dirty()
                  end
                },
                vb:text{
                  id = "curve_yR_value",
                  text = string.format("%.2f", curve_yR),
                  width = 35
                }
              }
        },
        
        -- RIGHT SIDE: Bézier curve visualization 
        vb:column{
          vb:text{
            text = "Curve Shape:",
            font = "bold"
          },
          vb:canvas{
            id = "bezier_canvas",
            width = 200,
            height = 120,
            render = render_bezier_canvas,
            mode = "transparent"
          }
        }
      },
      
      -- BELOW SLIDERS: Curve presets (FIXED LAYOUT!)
      vb:row{
        vb:button{
          text = "Linear",
          width = 45,
          notifier = function()
            apply_curve_preset("linear")
          end
        },
        vb:button{
          text = "Soft",
          width = 35,
          notifier = function()
            apply_curve_preset("soft")  
          end
        },
        vb:button{
          text = "Hard", 
          width = 35,
          notifier = function()
            apply_curve_preset("hard")
          end
        },
        vb:button{
          text = "Asym",
          width = 35,
          notifier = function()
            apply_curve_preset("asym")
          end
        }
      }
    }
      },
      
      -- Second row: Wet/Dry and Output
      vb:row{
        
        vb:column{
      vb:row{
      vb:text{
          text = "Dry:",
        font = "bold"
        },
        vb:slider{
              id = "dry_slider",
              min = 0.0,
              max = 1.0,
              value = dry_value,
              width = 120,
          notifier = function(value)
                dry_value = value
                if vb.views.dry_value then
                  vb.views.dry_value.text = string.format("%.2f", value)
            end
            mark_dirty()
          end
        },
        vb:text{
              id = "dry_value",
              text = string.format("%.2f", dry_value),
          width = 40
            }
        }
      },
      
        vb:column{
      vb:row{
        vb:text{
              text = "Wet:",
              font = "bold"
        },
  
        vb:slider{
          id = "wet_slider",
          min = 0.0,
          max = 1.0,
              value = wet_value,
              width = 120,
          notifier = function(value)
                wet_value = value
                if vb.views.wet_value then
                  vb.views.wet_value.text = string.format("%.2f", value)
            end
            mark_dirty()
          end
        },
        vb:text{
              id = "wet_value",
              text = string.format("%.2f", wet_value),
          width = 40
            }
        }
      },
      
        vb:column{
   
      vb:row{
        vb:text{
          text = "Output:",
                font = "bold"
        },
        vb:slider{
          id = "output_slider",
          min = 0.1,
          max = 2.0,
          value = output_gain_value,
              width = 120,
          notifier = function(value)
            output_gain_value = value
            if vb.views.output_value then
              vb.views.output_value.text = string.format("%.2f", value)
            end
            mark_dirty()
          end
        },
        vb:text{
          id = "output_value",
          text = string.format("%.2f", output_gain_value),
          width = 40
            }
          }
        }
      }
    },
    
    -- Visual Canvases
    vb:column{
      style = "group",
      
      vb:column{
        vb:canvas{
          id = "parameter_canvas",
          width = parameter_canvas_width,
          height = parameter_canvas_height,
          mode = "plain",
          render = render_parameter_canvas,
          mouse_handler = handle_parameter_canvas_mouse,
          mouse_events = {"down", "up", "move"}
        },
        
        -- Labels and values now drawn directly on canvas using PakettiCanvasFont
      },
      
      -- Waveform Canvas
      vb:column{
--        vb:text{
--          text = "Waveform Display (Blue=Original, Orange=Processed)",
--          font = "italic"
--        },
        vb:canvas{
          id = "waveform_canvas",
          width = waveform_canvas_width,
          height = waveform_canvas_height,
          mode = "plain",
          render = render_waveform_canvas,
          mouse_handler = function(ev)
            -- Stop parameter dragging if mouse is released on waveform canvas
            if ev.type == "up" and ev.button == "left" and is_dragging_param then
              is_dragging_param = false
              drag_param_type = nil
            end
          end,
          mouse_events = {"up"}
        }
      }
    },
    
    
    -- Auto-normalize checkbox
    vb:column{
      style = "group",
      
      vb:text{
        text = "Post-Processing:",
        font = "bold"
      },
      
      vb:row{
        vb:checkbox{
          value = auto_normalize_enabled,
          notifier = function(value)
            auto_normalize_enabled = value
          end
        },
        vb:text{
          text = "Auto-normalize after applying effect"
        }
      }
    },
    
    -- Harmonic Presets
    vb:column{
      style = "group",
      
      vb:text{
        text = "Harmonic Presets:",
        font = "bold"
      },
      
      vb:row{
        
        vb:button{
          text = "Equal",
          width = 70,
          notifier = function()
            apply_preset("equal")
          end
        },
        
        vb:button{
          text = "1/n Rolloff", 
          width = 80,
          notifier = function()
            apply_preset("rolloff")
          end
        },
        
        vb:button{
          text = "Traditional",
          width = 80,
          notifier = function()
            apply_preset("traditional")
          end
        },
        
        vb:button{
          text = "Clear All",
          width = 70,
          notifier = function()
            apply_preset("clear")
            renoise.app():show_status("Cleared all harmonic gains")
          end
        },
        
        vb:button{
          text = "Reset All",
          width = 70,
          notifier = function()
            apply_preset("reset_all")
            renoise.app():show_status("Reset all parameters to default")
          end
        },
        
        vb:button{
          text = "Randomize",
          width = 80,
          notifier = function()
            apply_preset("randomize")
            renoise.app():show_status("Randomized parameters for exploration")
          end
        }
      }
    },
    
    -- Musical Macros
    vb:column{
      style = "group",
      
      vb:text{
        text = "Musical Macros:",
        font = "bold"
      },
      
      vb:row{
        vb:button{
          text = "Scale -6dB",
          width = 80,
          notifier = function()
            scale_all(0.5)  -- -6dB
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Scaled all harmonics -6dB")
          end
        },
        
        vb:button{
          text = "Scale +6dB", 
          width = 80,
          notifier = function()
            scale_all(2.0)  -- +6dB
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Scaled all harmonics +6dB")
          end
        },
        
        vb:button{
          text = "Tilt ↑",
          width = 60,
          notifier = function()
            tilt_all(0.5)  -- Emphasize lower harmonics
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Applied upward tilt (lower harmonics boosted)")
          end
        },
        
        vb:button{
          text = "Tilt ↓",
          width = 60,
          notifier = function()
            tilt_all(-0.5)  -- Emphasize higher harmonics
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Applied downward tilt (higher harmonics boosted)")
          end
        }
      },
      
      vb:row{
        vb:button{
          text = "Odd +2dB",
          width = 80,
          notifier = function()
            set_odd_even(1.26, 1.0)  -- +2dB for odd, unchanged for even
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Boosted odd harmonics +2dB")
          end
        },
        
        vb:button{
          text = "Even +2dB",
          width = 80,
          notifier = function()
            set_odd_even(1.0, 1.26)  -- unchanged for odd, +2dB for even
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Boosted even harmonics +2dB")
          end
        },
        
        vb:button{
          text = "Odd -2dB",
          width = 80,
          notifier = function()
            set_odd_even(0.79, 1.0)  -- -2dB for odd, unchanged for even
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Cut odd harmonics -2dB")
          end
        },
        
        vb:button{
          text = "Even -2dB",
          width = 80,
          notifier = function()
            set_odd_even(1.0, 0.79)  -- unchanged for odd, -2dB for even
            -- FIXED: Update canvas immediately for instant visual feedback!
            if parameter_canvas then parameter_canvas:update() end
            mark_dirty()
            renoise.app():show_status("Cut even harmonics -2dB")
          end
        }
      }
    },
    
    -- Control buttons
    vb:column{
      style = "group",
      
      vb:row{
        vb:button{
          text = preview_enabled and "Disable Preview" or "Enable Preview",
          width = 120,
          id = "preview_button",
          notifier = toggle_preview
        },
        
        vb:button{
          text = "Reset",
          width = 80,
          notifier = reset_sample
        }
      },
      
      
      vb:row{
        
        vb:button{
          text = "Apply",
          width = 80,
          notifier = apply_processing
        },
        
        vb:button{
          text = "Normalize",
          width = 80,
          notifier = apply_normalization
        },
        
        vb:button{
          text = "Close",
          width = 80,
          notifier = function()
            if preview_enabled then
              preview_enabled = false
              restore_sample_range()
            end
            backup_sample_data = nil
            -- Remove idle notifier to prevent memory leaks
            pcall(function() renoise.tool().app_idle_observable:remove_notifier(idle_tick) end)
            dialog:close()
          end
        }
      }
    }
  }

  -- Show dialog with key handler
  dialog = renoise.app():show_custom_dialog("Paketti Chebyshev/Magnet Waveshaper", content, my_keyhandler_func)
  
  -- Add idle notifier for debounced rebuilds
  renoise.tool().app_idle_observable:add_notifier(idle_tick)
  
  -- Initialize canvas references
  parameter_canvas = vb.views.parameter_canvas
  waveform_canvas = vb.views.waveform_canvas
  bezier_canvas = vb.views.bezier_canvas  -- NEW: Store Bézier canvas reference
  
  -- Initialize canvas displays
  update_canvas_displays()
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Chebyshev Polynomial Waveshaper...",invoke = show_chebyshev_waveshaper}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti Gadgets:Chebyshev Polynomial Waveshaper...",invoke = show_chebyshev_waveshaper}

renoise.tool():add_keybinding{name = "Global:Paketti:Show Chebyshev Polynomial Waveshaper",invoke = show_chebyshev_waveshaper}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Show Chebyshev Polynomial Waveshaper",invoke = show_chebyshev_waveshaper} 
