-- PakettiXMLizer.lua
-- Custom LFO Preset System for Renoise with 16 preference-stored slots
-- Uses XML injection via device.active_preset_data

local xmlizer_presets = {}

-- Function to generate XML for LFO device with custom envelope points
function generate_lfo_xml(amplitude, offset, frequency, lfo_type, envelope_points)
  local points_xml = ""
  for i, point in ipairs(envelope_points) do
    local step = point[1]
    local value = point[2]
    local scaling = point[3] or 0.0
    points_xml = points_xml .. string.format("        <Point>%d,%g,%g</Point>\n", step, value, scaling)
  end
  
  local xml_template = [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>%g</Value>
    </Amplitude>
    <Offset>
      <Value>%g</Value>
    </Offset>
    <Frequency>
      <Value>%g</Value>
    </Frequency>
    <Type>
      <Value>%d</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>1024</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
%s      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]]

  return string.format(xml_template, amplitude, offset, frequency, lfo_type, points_xml)
end

-- Custom LFO Preset 1: The original complex curve
xmlizer_presets.custom_lfo_1 = {
  name = "Custom LFO Preset 1",
  description = "Original complex curve with 1024 steps",
  xml_data = [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>1.0</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>0.46874997</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>1024</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.0472103022,0.0</Point>
        <Point>8,0.139484972,0.0</Point>
        <Point>16,0.223175973,0.0</Point>
        <Point>24,0.293991417,0.0</Point>
        <Point>32,0.360515028,0.0</Point>
        <Point>40,0.423819721,0.0</Point>
        <Point>48,0.475536495,0.0</Point>
        <Point>56,0.520386219,0.0</Point>
        <Point>64,0.565450668,0.0</Point>
        <Point>72,0.620171666,0.0</Point>
        <Point>80,0.684549332,0.0</Point>
        <Point>88,0.740343332,0.0</Point>
        <Point>96,0.779685199,0.0</Point>
        <Point>104,0.814020038,0.0</Point>
        <Point>112,0.851931334,0.0</Point>
        <Point>120,0.888411999,0.0</Point>
        <Point>128,0.908798277,0.0</Point>
        <Point>136,0.916308999,0.0</Point>
        <Point>144,0.933476388,0.0</Point>
        <Point>152,0.950643778,0.0</Point>
        <Point>160,0.974248946,0.0</Point>
        <Point>168,0.992489278,0.0</Point>
        <Point>176,1.0,0.0</Point>
        <Point>184,1.0,0.0</Point>
        <Point>192,1.0,0.0</Point>
        <Point>200,1.0,0.0</Point>
        <Point>208,1.0,0.0</Point>
        <Point>216,1.0,0.0</Point>
        <Point>224,1.0,0.0</Point>
        <Point>232,1.0,0.0</Point>
        <Point>240,1.0,0.0</Point>
        <Point>248,1.0,0.0</Point>
        <Point>256,1.0,0.0</Point>
        <Point>264,1.0,0.0</Point>
        <Point>272,1.0,0.0</Point>
        <Point>280,0.972103,0.0</Point>
        <Point>288,0.942060113,0.0</Point>
        <Point>296,0.91684556,0.0</Point>
        <Point>304,0.892703891,0.0</Point>
        <Point>312,0.871959925,0.0</Point>
        <Point>320,0.847281814,0.0</Point>
        <Point>328,0.827253222,0.0</Point>
        <Point>336,0.800429165,0.0</Point>
        <Point>344,0.772532165,0.0</Point>
        <Point>352,0.729613721,0.0</Point>
        <Point>360,0.681330442,0.0</Point>
        <Point>368,0.622317612,0.0</Point>
        <Point>376,0.566523612,0.0</Point>
        <Point>384,0.515736759,0.0</Point>
        <Point>392,0.469957083,0.0</Point>
        <Point>400,0.42703864,0.0</Point>
        <Point>408,0.388412029,0.0</Point>
        <Point>416,0.351931334,0.0</Point>
        <Point>424,0.313304722,0.0</Point>
        <Point>432,0.283261806,0.0</Point>
        <Point>440,0.266094416,0.0</Point>
        <Point>448,0.253218889,0.0</Point>
        <Point>456,0.253218889,0.0</Point>
        <Point>464,0.233905584,0.0</Point>
        <Point>472,0.197424889,0.0</Point>
        <Point>480,0.156652361,0.0</Point>
        <Point>488,0.0965665206,0.0</Point>
        <Point>496,0.0429184549,0.0</Point>
        <Point>501,0.0300429184,0.0</Point>
        <Point>504,0.0343347639,0.0</Point>
        <Point>512,0.0901287496,0.0</Point>
        <Point>520,0.149141639,0.0</Point>
        <Point>528,0.193133056,0.0</Point>
        <Point>536,0.242489263,0.0</Point>
        <Point>544,0.298283279,0.0</Point>
        <Point>552,0.372317612,0.0</Point>
        <Point>560,0.447067231,0.0</Point>
        <Point>568,0.506437778,0.0</Point>
        <Point>576,0.568669558,0.0</Point>
        <Point>584,0.61802578,0.0</Point>
        <Point>592,0.655794024,0.0</Point>
        <Point>600,0.687768221,0.0</Point>
        <Point>608,0.701716721,0.0</Point>
        <Point>616,0.713519275,0.0</Point>
        <Point>624,0.729613721,0.0</Point>
        <Point>632,0.759656668,0.0</Point>
        <Point>640,0.814377666,0.0</Point>
        <Point>648,0.834287047,0.0</Point>
        <Point>656,0.849546969,0.0</Point>
        <Point>664,0.86480689,0.0</Point>
        <Point>672,0.881437719,0.0</Point>
        <Point>680,0.89592278,0.0</Point>
        <Point>688,0.910177767,0.0</Point>
        <Point>696,0.924892724,0.0</Point>
        <Point>704,0.939914167,0.0</Point>
        <Point>712,0.959227443,0.0</Point>
        <Point>720,0.974964261,0.0</Point>
        <Point>728,0.987124443,0.0</Point>
        <Point>736,0.993562222,0.0</Point>
        <Point>744,0.995708168,0.0</Point>
        <Point>752,0.995708168,0.0</Point>
        <Point>760,0.997854054,0.0</Point>
        <Point>768,0.997854054,0.0</Point>
        <Point>776,0.997854054,0.0</Point>
        <Point>784,0.997854054,0.0</Point>
        <Point>792,0.994635224,0.0</Point>
        <Point>800,0.984978557,0.0</Point>
        <Point>808,0.969957054,0.0</Point>
        <Point>816,0.952789724,0.0</Point>
        <Point>824,0.936158776,0.0</Point>
        <Point>832,0.923175991,0.0</Point>
        <Point>840,0.909871221,0.0</Point>
        <Point>848,0.896995723,0.0</Point>
        <Point>856,0.879828334,0.0</Point>
        <Point>864,0.847639501,0.0</Point>
        <Point>872,0.816308975,0.0</Point>
        <Point>880,0.785050035,0.0</Point>
        <Point>888,0.752789736,0.0</Point>
        <Point>896,0.721030056,0.0</Point>
        <Point>904,0.68168813,0.0</Point>
        <Point>912,0.596566498,0.0</Point>
        <Point>920,0.418454945,0.0</Point>
        <Point>928,0.384120166,0.0</Point>
        <Point>936,0.361230314,0.0</Point>
        <Point>944,0.328326166,0.0</Point>
        <Point>952,0.289699584,0.0</Point>
        <Point>960,0.246781126,0.0</Point>
        <Point>968,0.198140204,0.0</Point>
        <Point>976,0.148068666,0.0</Point>
        <Point>984,0.100858368,0.0</Point>
        <Point>992,0.0622317605,0.0</Point>
        <Point>1000,0.0278969966,0.0</Point>
        <Point>1008,0.00429184549,0.0</Point>
        <Point>1016,0.0,0.0</Point>
        <Point>1023,0.0,0.0</Point>
        <Point>1024,0.0,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]]
}

-- Custom LFO Preset 2: Linear Ramp from 0.0 to 1.0
xmlizer_presets.custom_lfo_2 = {
  name = "Custom LFO Preset 2",
  description = "Linear ramp from 0.0 to 1.0 over 1024 steps",
  xml_data = function()
    local envelope_points = {}
    -- Create linear ramp from 0.0 to 1.0 over 1024 steps
    for step = 0, 1024, 32 do
      local value = step / 1024.0
      if step == 1024 then
        value = 1.0  -- Ensure we end exactly at 1.0
      end
      table.insert(envelope_points, {step, value, 0.0})
    end
    return generate_lfo_xml(1.0, 0.0, 0.25, 4, envelope_points)
  end
}

-- Custom LFO Preset 3: Sine Wave (2 complete cycles from 0→1→0→1→0)
xmlizer_presets.custom_lfo_3 = {
  name = "Custom LFO Preset 3",
  description = "Sine wave - 2 complete cycles (0→1→0→1→0) over 1024 steps",
  xml_data = function()
    local envelope_points = {}
    -- Create sine wave with 2 complete cycles over 1024 steps
    for step = 0, 1024, 16 do
      -- 2 complete cycles: 2 * 2 * pi * step / 1024
      -- Scale from [-1,1] to [0,1]: (sin(x) + 1) / 2
      local angle = 2 * math.pi * 2 * step / 1024
      local value = (math.sin(angle) + 1) / 2
      
      -- Ensure we end exactly where we started (at 0)
      if step == 1024 then
        value = 0.0
      end
      
      table.insert(envelope_points, {step, value, 0.0})
    end
    return generate_lfo_xml(1.0, 0.0, 0.25, 4, envelope_points)
  end
}

-- Custom LFO Preset 4: Random Noise (1024 random steps between 0.0-1.0)
xmlizer_presets.custom_lfo_4 = {
  name = "Custom LFO Preset 4",
  description = "Random noise - 1024 random values between 0.0 and 1.0",
  xml_data = function()
    local envelope_points = {}
    -- Create 1024 random points between 0.0 and 1.0
    for step = 0, 1024 do
      local value = math.random()  -- Random value between 0.0 and 1.0
      table.insert(envelope_points, {step, value, 0.0})
    end
    return generate_lfo_xml(1.0, 0.0, 0.25, 4, envelope_points)
  end
}

-- Custom LFO Preset 5: User provided XML
xmlizer_presets.custom_lfo_5 = {
  name = "Custom LFO Preset 5",
  description = "User provided complex envelope",
  xml_data = [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>1.0</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>0.25</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>1024</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.0,0.0</Point>
        <Point>16,0.300429195,0.0</Point>
        <Point>24,0.360515028,0.0</Point>
        <Point>32,0.410109669,0.0</Point>
        <Point>40,0.45686692,0.0</Point>
        <Point>48,0.502414167,0.0</Point>
        <Point>56,0.540772438,0.0</Point>
        <Point>64,0.576609612,0.0</Point>
        <Point>72,0.607296169,0.0</Point>
        <Point>80,0.627145946,0.0</Point>
        <Point>88,0.625536501,0.0</Point>
        <Point>96,0.58690989,0.0</Point>
        <Point>104,0.515021503,0.0</Point>
        <Point>112,0.435622305,0.0</Point>
        <Point>120,0.343347609,0.0</Point>
        <Point>128,0.278969944,0.0</Point>
        <Point>136,0.28111589,0.0</Point>
        <Point>144,0.323229611,0.0</Point>
        <Point>152,0.36940527,0.0</Point>
        <Point>160,0.423700541,0.0</Point>
        <Point>168,0.478847325,0.0</Point>
        <Point>176,0.535622299,0.0</Point>
        <Point>184,0.597281814,0.0</Point>
        <Point>192,0.648068666,0.0</Point>
        <Point>200,0.644205987,0.0</Point>
        <Point>208,0.604230464,0.0</Point>
        <Point>216,0.556330502,0.0</Point>
        <Point>224,0.503372252,0.0</Point>
        <Point>232,0.446351945,0.0</Point>
        <Point>240,0.394849777,0.0</Point>
        <Point>248,0.356223166,0.0</Point>
        <Point>256,0.334763944,0.0</Point>
        <Point>264,0.348497838,0.0</Point>
        <Point>272,0.375536472,0.0</Point>
        <Point>280,0.400214583,0.0</Point>
        <Point>288,0.424892694,0.0</Point>
        <Point>296,0.446351945,0.0</Point>
        <Point>304,0.386266083,0.0</Point>
        <Point>312,0.319742501,0.0</Point>
        <Point>320,0.346566528,0.0</Point>
        <Point>328,0.405579388,0.0</Point>
        <Point>336,0.48283267,0.0</Point>
        <Point>344,0.523605168,0.0</Point>
        <Point>352,0.565665245,0.0</Point>
        <Point>360,0.612017095,0.0</Point>
        <Point>368,0.666845322,0.0</Point>
        <Point>376,0.71888411,0.0</Point>
        <Point>384,0.76046139,0.0</Point>
        <Point>392,0.801144481,0.0</Point>
        <Point>400,0.841201723,0.0</Point>
        <Point>408,0.875536382,0.0</Point>
        <Point>416,0.904863954,0.0</Point>
        <Point>424,0.930745065,0.0</Point>
        <Point>432,0.954399109,0.0</Point>
        <Point>440,0.974249005,0.0</Point>
        <Point>448,0.98980689,0.0</Point>
        <Point>456,0.998658717,0.0</Point>
        <Point>464,1.0,0.0</Point>
        <Point>472,0.997853994,0.0</Point>
        <Point>480,0.977110088,0.0</Point>
        <Point>488,0.92703861,0.0</Point>
        <Point>496,0.833691001,0.0</Point>
        <Point>504,0.728540778,0.0</Point>
        <Point>512,0.626609445,0.0</Point>
        <Point>520,0.555793941,0.0</Point>
        <Point>528,0.508583665,0.0</Point>
        <Point>536,0.488197446,0.0</Point>
        <Point>544,0.479256034,0.0</Point>
        <Point>552,0.474785477,0.0</Point>
        <Point>560,0.472579777,0.0</Point>
        <Point>568,0.470932484,0.0</Point>
        <Point>576,0.469313323,0.0</Point>
        <Point>584,0.467572719,0.0</Point>
        <Point>592,0.465665221,0.0</Point>
        <Point>600,0.463519305,0.0</Point>
        <Point>608,0.463519305,0.0</Point>
        <Point>616,0.463519305,0.0</Point>
        <Point>624,0.515021443,0.0</Point>
        <Point>632,0.481974244,0.0</Point>
        <Point>640,0.441344798,0.0</Point>
        <Point>648,0.394313306,0.0</Point>
        <Point>656,0.34477824,0.0</Point>
        <Point>664,0.29881978,0.0</Point>
        <Point>672,0.261087239,0.0</Point>
        <Point>680,0.241952777,0.0</Point>
        <Point>688,0.242489263,0.0</Point>
        <Point>696,0.264902264,0.0</Point>
        <Point>704,0.304525942,0.0</Point>
        <Point>712,0.354467481,0.0</Point>
        <Point>720,0.427467883,0.0</Point>
        <Point>728,0.506767929,0.0</Point>
        <Point>736,0.584681213,0.0</Point>
        <Point>744,0.674535096,0.0</Point>
        <Point>752,0.762017131,0.0</Point>
        <Point>760,0.84167856,0.0</Point>
        <Point>768,0.914163113,0.0</Point>
        <Point>776,0.978540778,0.0</Point>
        <Point>784,1.0,0.0</Point>
        <Point>792,1.0,0.0</Point>
        <Point>800,1.0,0.0</Point>
        <Point>808,1.0,0.0</Point>
        <Point>816,1.0,0.0</Point>
        <Point>824,1.0,0.0</Point>
        <Point>832,1.0,0.0</Point>
        <Point>840,0.990343332,0.0</Point>
        <Point>848,0.964592218,0.0</Point>
        <Point>856,0.938841105,0.0</Point>
        <Point>864,0.901823997,0.0</Point>
        <Point>872,0.863197386,0.0</Point>
        <Point>880,0.814735353,0.0</Point>
        <Point>888,0.782188833,0.0</Point>
        <Point>896,0.751072943,0.0</Point>
        <Point>904,0.740343332,0.0</Point>
        <Point>912,0.740343332,0.0</Point>
        <Point>920,0.740343332,0.0</Point>
        <Point>928,0.74302578,0.0</Point>
        <Point>936,0.744635165,0.0</Point>
        <Point>944,0.746781111,0.0</Point>
        <Point>952,0.743919849,0.0</Point>
        <Point>960,0.730686724,0.0</Point>
        <Point>968,0.705472112,0.0</Point>
        <Point>976,0.671673834,0.0</Point>
        <Point>984,0.603004277,0.0</Point>
        <Point>992,0.437768221,0.0</Point>
        <Point>1000,0.45493561,0.0</Point>
        <Point>1008,0.469957083,0.0</Point>
        <Point>1016,0.485563725,0.0</Point>
        <Point>1023,0.626609445,0.0</Point>
        <Point>1024,0.530042946,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]]
}

-- Custom LFO Preset 6: Inverted version of Custom LFO Preset 1
xmlizer_presets.custom_lfo_6 = {
  name = "Custom LFO Preset 6",
  description = "Inverted version of Custom LFO Preset 1",
  xml_data = [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>1.0</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>0.46874997</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>1024</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.9527896978,0.0</Point>
        <Point>8,0.860515028,0.0</Point>
        <Point>16,0.776824027,0.0</Point>
        <Point>24,0.706008583,0.0</Point>
        <Point>32,0.639484972,0.0</Point>
        <Point>40,0.576180279,0.0</Point>
        <Point>48,0.524463505,0.0</Point>
        <Point>56,0.479613781,0.0</Point>
        <Point>64,0.434549332,0.0</Point>
        <Point>72,0.379828334,0.0</Point>
        <Point>80,0.315450668,0.0</Point>
        <Point>88,0.259656668,0.0</Point>
        <Point>96,0.220314801,0.0</Point>
        <Point>104,0.185979962,0.0</Point>
        <Point>112,0.148068666,0.0</Point>
        <Point>120,0.111588001,0.0</Point>
        <Point>128,0.091201723,0.0</Point>
        <Point>136,0.083691001,0.0</Point>
        <Point>144,0.066523612,0.0</Point>
        <Point>152,0.049356222,0.0</Point>
        <Point>160,0.025751054,0.0</Point>
        <Point>168,0.007510722,0.0</Point>
        <Point>176,0.0,0.0</Point>
        <Point>184,0.0,0.0</Point>
        <Point>192,0.0,0.0</Point>
        <Point>200,0.0,0.0</Point>
        <Point>208,0.0,0.0</Point>
        <Point>216,0.0,0.0</Point>
        <Point>224,0.0,0.0</Point>
        <Point>232,0.0,0.0</Point>
        <Point>240,0.0,0.0</Point>
        <Point>248,0.0,0.0</Point>
        <Point>256,0.0,0.0</Point>
        <Point>264,0.0,0.0</Point>
        <Point>272,0.0,0.0</Point>
        <Point>280,0.027897,0.0</Point>
        <Point>288,0.057939887,0.0</Point>
        <Point>296,0.08315444,0.0</Point>
        <Point>304,0.107296109,0.0</Point>
        <Point>312,0.128040075,0.0</Point>
        <Point>320,0.152718186,0.0</Point>
        <Point>328,0.172746778,0.0</Point>
        <Point>336,0.199570835,0.0</Point>
        <Point>344,0.227467835,0.0</Point>
        <Point>352,0.270386279,0.0</Point>
        <Point>360,0.318669558,0.0</Point>
        <Point>368,0.377682388,0.0</Point>
        <Point>376,0.433476388,0.0</Point>
        <Point>384,0.484263241,0.0</Point>
        <Point>392,0.530042917,0.0</Point>
        <Point>400,0.57296136,0.0</Point>
        <Point>408,0.611587971,0.0</Point>
        <Point>416,0.648068666,0.0</Point>
        <Point>424,0.686695278,0.0</Point>
        <Point>432,0.716738194,0.0</Point>
        <Point>440,0.733905584,0.0</Point>
        <Point>448,0.746781111,0.0</Point>
        <Point>456,0.746781111,0.0</Point>
        <Point>464,0.766094416,0.0</Point>
        <Point>472,0.802575111,0.0</Point>
        <Point>480,0.843347639,0.0</Point>
        <Point>488,0.9034334794,0.0</Point>
        <Point>496,0.9570815451,0.0</Point>
        <Point>501,0.9699570816,0.0</Point>
        <Point>504,0.9656652361,0.0</Point>
        <Point>512,0.9098712504,0.0</Point>
        <Point>520,0.850858361,0.0</Point>
        <Point>528,0.806866944,0.0</Point>
        <Point>536,0.757510737,0.0</Point>
        <Point>544,0.701716721,0.0</Point>
        <Point>552,0.627682388,0.0</Point>
        <Point>560,0.552932769,0.0</Point>
        <Point>568,0.493562222,0.0</Point>
        <Point>576,0.431330442,0.0</Point>
        <Point>584,0.38197422,0.0</Point>
        <Point>592,0.344205976,0.0</Point>
        <Point>600,0.312231779,0.0</Point>
        <Point>608,0.298283279,0.0</Point>
        <Point>616,0.286480725,0.0</Point>
        <Point>624,0.270386279,0.0</Point>
        <Point>632,0.240343332,0.0</Point>
        <Point>640,0.185622334,0.0</Point>
        <Point>648,0.165712953,0.0</Point>
        <Point>656,0.150453031,0.0</Point>
        <Point>664,0.13519311,0.0</Point>
        <Point>672,0.118562281,0.0</Point>
        <Point>680,0.10407722,0.0</Point>
        <Point>688,0.089822233,0.0</Point>
        <Point>696,0.075107276,0.0</Point>
        <Point>704,0.060085833,0.0</Point>
        <Point>712,0.040772557,0.0</Point>
        <Point>720,0.025035739,0.0</Point>
        <Point>728,0.012875557,0.0</Point>
        <Point>736,0.006437778,0.0</Point>
        <Point>744,0.004291832,0.0</Point>
        <Point>752,0.004291832,0.0</Point>
        <Point>760,0.002145946,0.0</Point>
        <Point>768,0.002145946,0.0</Point>
        <Point>776,0.002145946,0.0</Point>
        <Point>784,0.002145946,0.0</Point>
        <Point>792,0.005364776,0.0</Point>
        <Point>800,0.015021443,0.0</Point>
        <Point>808,0.030042946,0.0</Point>
        <Point>816,0.047210276,0.0</Point>
        <Point>824,0.063841224,0.0</Point>
        <Point>832,0.076824009,0.0</Point>
        <Point>840,0.090128779,0.0</Point>
        <Point>848,0.103004277,0.0</Point>
        <Point>856,0.120171666,0.0</Point>
        <Point>864,0.152360499,0.0</Point>
        <Point>872,0.183691025,0.0</Point>
        <Point>880,0.214949965,0.0</Point>
        <Point>888,0.247210264,0.0</Point>
        <Point>896,0.278969944,0.0</Point>
        <Point>904,0.31831187,0.0</Point>
        <Point>912,0.403433502,0.0</Point>
        <Point>920,0.581545055,0.0</Point>
        <Point>928,0.615879834,0.0</Point>
        <Point>936,0.638769686,0.0</Point>
        <Point>944,0.671673834,0.0</Point>
        <Point>952,0.710300416,0.0</Point>
        <Point>960,0.753218874,0.0</Point>
        <Point>968,0.801859796,0.0</Point>
        <Point>976,0.851931334,0.0</Point>
        <Point>984,0.899141632,0.0</Point>
        <Point>992,0.9377682395,0.0</Point>
        <Point>1000,0.9721030034,0.0</Point>
        <Point>1008,0.99570815451,0.0</Point>
        <Point>1016,1.0,0.0</Point>
        <Point>1023,1.0,0.0</Point>
        <Point>1024,1.0,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]]
}

-- Generate XML for presets that use functions
for key, preset in pairs(xmlizer_presets) do
  if type(preset.xml_data) == "function" then
    preset.xml_data = preset.xml_data()
  end
end

-- Function to check if a device is an LFO device
function is_lfo_device(device)
  if device and device.device_path then
    return device.device_path == "Audio/Effects/Native/*LFO"
  end
  return false
end

-- Function to load LFO device if none exists or if current device is not LFO
function ensure_lfo_device_selected()
  local device = renoise.song().selected_device
  
  if device and is_lfo_device(device) then
    print("PakettiXMLizer: LFO device already selected")
    return true
  end
  
  local track = renoise.song().selected_track
  if not track then
    print("PakettiXMLizer: Error - No track selected")
    return false
  end
  
  print("PakettiXMLizer: Loading LFO device...")
  local lfo_device = track:insert_device_at("Audio/Effects/Native/*LFO", #track.devices + 1)
  
  if lfo_device then
    print("PakettiXMLizer: Successfully loaded LFO device")
    return true
  else
    print("PakettiXMLizer: Failed to load LFO device")
    return false
  end
end

-- Function to store current LFO device XML to preference slot
function pakettiStoreCustomLFO(slot_number)
  if slot_number < 1 or slot_number > 16 then
    print("PakettiXMLizer: Error - Invalid slot number: " .. slot_number)
    renoise.app():show_status("PakettiXMLizer: Invalid slot number")
    return
  end
  
  local device = renoise.song().selected_device
  if not device or not is_lfo_device(device) then
    print("PakettiXMLizer: Error - Selected device is not an LFO device")
    renoise.app():show_status("PakettiXMLizer: Please select an LFO device first")
    return
  end
  
  local xml_data = device.active_preset_data
  if not xml_data or xml_data == "" then
    print("PakettiXMLizer: Error - No preset data found in LFO device")
    renoise.app():show_status("PakettiXMLizer: No preset data to store")
    return
  end
  
  -- Store in preferences
  local pref_key = "pakettiCustomLFOXMLInject" .. slot_number
  preferences.PakettiXMLizer[pref_key].value = xml_data
  
  print("PakettiXMLizer: Stored LFO preset to slot " .. slot_number)
  renoise.app():show_status("PakettiXMLizer: Stored LFO preset to slot " .. slot_number)
end

-- Function to load XML from preference slot to current LFO device
function pakettiLoadCustomLFO(slot_number)
  if slot_number < 1 or slot_number > 16 then
    print("PakettiXMLizer: Error - Invalid slot number: " .. slot_number)
    renoise.app():show_status("PakettiXMLizer: Invalid slot number")
    return
  end
  
  if not ensure_lfo_device_selected() then
    renoise.app():show_status("PakettiXMLizer: Failed to ensure LFO device is available")
    return
  end
  
  local device = renoise.song().selected_device
  if not device or not is_lfo_device(device) then
    print("PakettiXMLizer: Error - Selected device is not an LFO device")
    renoise.app():show_status("PakettiXMLizer: Selected device is not an LFO device")
    return
  end
  
  -- Load from preferences
  local pref_key = "pakettiCustomLFOXMLInject" .. slot_number
  local xml_data = preferences.PakettiXMLizer[pref_key].value
  
  if not xml_data or xml_data == "" then
    print("PakettiXMLizer: No preset stored in slot " .. slot_number)
    renoise.app():show_status("PakettiXMLizer: No preset stored in slot " .. slot_number)
    return
  end
  
  -- Inject the XML
  print("PakettiXMLizer: Loading LFO preset from slot " .. slot_number)
  device.active_preset_data = xml_data
  
  print("PakettiXMLizer: Successfully loaded preset from slot " .. slot_number)
  renoise.app():show_status("PakettiXMLizer: Loaded LFO preset from slot " .. slot_number)
end

-- Function to apply hardcoded presets
function pakettiApplyCustomLFO(number)
  if number < 1 or number > 6 then
    print("PakettiXMLizer: Error - Invalid preset number: " .. number)
    renoise.app():show_status("PakettiXMLizer: Invalid preset number")
    return
  end
  
  if not ensure_lfo_device_selected() then
    renoise.app():show_status("PakettiXMLizer: Failed to ensure LFO device is available")
    return
  end
  
  local device = renoise.song().selected_device
  if not device or not is_lfo_device(device) then
    print("PakettiXMLizer: Error - Selected device is not an LFO device")
    renoise.app():show_status("PakettiXMLizer: Selected device is not an LFO device")
    return
  end
  
  local preset_key = "custom_lfo_" .. number
  local preset = xmlizer_presets[preset_key]
  
  if not preset then
    print("PakettiXMLizer: Error - Preset " .. number .. " not found")
    renoise.app():show_status("PakettiXMLizer: Preset " .. number .. " not found")
    return
  end
  
  print("PakettiXMLizer: Applying Custom LFO Preset " .. number)
  device.active_preset_data = preset.xml_data
  renoise.app():show_status("PakettiXMLizer: Applied Custom LFO Preset " .. number)
end

-- Register keybindings and menu entries for hardcoded presets
for i = 1, 6 do
  renoise.tool():add_keybinding{name="Global:Paketti:Apply Custom LFO Preset " .. i, invoke=function() pakettiApplyCustomLFO(i) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Apply Custom LFO Preset " .. i, invoke=function() pakettiApplyCustomLFO(i) end}
  renoise.tool():add_menu_entry{name="DSP Device:Paketti:Custom LFO Envelopes:Apply Custom LFO Preset " .. i, invoke=function() pakettiApplyCustomLFO(i) end}
end

-- Register menu entries for storing
for i = 1, 16 do
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Store Current LFO to Slot " .. i, invoke=function() pakettiStoreCustomLFO(i) end}
  renoise.tool():add_menu_entry{name="DSP Device:Paketti:Custom LFO Envelopes:Store Current LFO to Slot " .. i, invoke=function() pakettiStoreCustomLFO(i) end}
end

-- Register menu entries for loading
for i = 1, 16 do
  local menu_prefix = (i == 1) and "--" or ""
  renoise.tool():add_menu_entry{name=menu_prefix .. "Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Load LFO from Slot " .. i, invoke=function() pakettiLoadCustomLFO(i) end}
  renoise.tool():add_menu_entry{name=menu_prefix .. "DSP Device:Paketti:Custom LFO Envelopes:Load LFO from Slot " .. i, invoke=function() pakettiLoadCustomLFO(i) end}
end

-- Register keybindings for slots
for i = 1, 16 do
  renoise.tool():add_keybinding{name="Global:Paketti:Store Current LFO to Slot " .. i, invoke=function() pakettiStoreCustomLFO(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Load LFO from Slot " .. i, invoke=function() pakettiLoadCustomLFO(i) end}
end

-- Function to double LFO envelope resolution by duplicating each point
function pakettiDoubleLFOResolution()
  local device = renoise.song().selected_device
  
  -- Check if LFO device is selected
  if not device or not is_lfo_device(device) then
    renoise.app():show_status("PakettiXMLizer: Please select an LFO device first")
    print("PakettiXMLizer: Error - No LFO device selected")
    return
  end
  
  local xml_data = device.active_preset_data
  if not xml_data or xml_data == "" then
    renoise.app():show_status("PakettiXMLizer: No LFO preset data found")
    print("PakettiXMLizer: Error - No preset data in LFO device")
    return
  end
  
  print("=== DEBUG: Original XML Data ===")
  print(xml_data)
  print("=== END Original XML ===")
  
  -- Extract envelope length first
  local current_length = 4  -- default
  local length_match = xml_data:match("<Length>(%d+)</Length>")
  if length_match then
    current_length = tonumber(length_match)
  end
  print("=== DEBUG: Current envelope length: " .. current_length .. " ===")
  
  -- Extract only points within the current length range
  local points = {}
  local point_count = 0
  
  print("=== DEBUG: Extracting Points (within length range 0-" .. (current_length-1) .. ") ===")
  for point_line in xml_data:gmatch("<Point>([^<]+)</Point>") do
    print("Found point line: " .. point_line)
    local step, value, scaling = point_line:match("([^,]+),([^,]+),([^,]+)")
    if step and value and scaling then
      local step_num = tonumber(step)
      local point = {
        step = step_num,
        value = tonumber(value), 
        scaling = tonumber(scaling)
      }
      
      -- Only include points within the current length range
      if step_num < current_length then
        point_count = point_count + 1
        table.insert(points, point)
        print(string.format("Included point %d: step=%d, value=%g, scaling=%g", point_count, point.step, point.value, point.scaling))
      else
        print(string.format("Skipped point beyond length: step=%d (length=%d)", step_num, current_length))
      end
    else
      print("Failed to parse point: " .. point_line)
    end
  end
  print("=== END Extracting Points ===")
  
  if point_count == 0 then
    renoise.app():show_status("PakettiXMLizer: No envelope points found in LFO")
    print("PakettiXMLizer: Error - No envelope points found")
    return
  end
  
  -- Check if doubling would exceed limits
  local new_point_count = point_count * 2
  if new_point_count > 1024 then
    renoise.app():show_status(string.format("PakettiXMLizer: Can't double - %d points would exceed 1024 limit", new_point_count))
    print(string.format("PakettiXMLizer: Error - Doubling %d points would create %d points (exceeds 1024 limit)", point_count, new_point_count))
    return
  end
  
  -- Check if doubling step positions would exceed 1024 limit
  local max_doubled_step = points[#points].step * 2 + 1
  if max_doubled_step > 1024 then
    renoise.app():show_status(string.format("PakettiXMLizer: Can't double - max step %d would exceed 1024 limit", max_doubled_step))
    print(string.format("PakettiXMLizer: Error - Doubling max step position %d would create step %d (exceeds 1024 limit)", points[#points].step, max_doubled_step))
    return
  end
  
  print(string.format("PakettiXMLizer: Doubling LFO resolution from %d to %d points", point_count, new_point_count))
  
  -- Create doubled points by duplicating each point in sequence
  local doubled_points = {}
  print("=== DEBUG: Creating Doubled Points ===")
  for i, point in ipairs(points) do
    local new_step_1 = (point.step * 2)
    local new_step_2 = (point.step * 2) + 1
    
    -- Add first duplicate
    local dup1 = {
      step = new_step_1,
      value = point.value,
      scaling = point.scaling
    }
    table.insert(doubled_points, dup1)
    print(string.format("Added duplicate 1 of point at step %d: new_step=%d, value=%g", point.step, dup1.step, dup1.value))
    
    -- Add second duplicate
    local dup2 = {
      step = new_step_2,
      value = point.value,
      scaling = point.scaling
    }
    table.insert(doubled_points, dup2)
    print(string.format("Added duplicate 2 of point at step %d: new_step=%d, value=%g", point.step, dup2.step, dup2.value))
  end
  print("=== END Creating Doubled Points ===")
  
  -- Rebuild the points XML section
  print("=== DEBUG: Building New XML Points ===")
  local new_points_xml = ""
  for i, point in ipairs(doubled_points) do
    local point_xml = string.format("        <Point>%d,%g,%g</Point>\n", 
      point.step, point.value, point.scaling)
    new_points_xml = new_points_xml .. point_xml
    print(string.format("Point %d XML: %s", i, point_xml:gsub("\n", "")))
  end
  print("=== Complete New Points XML ===")
  print(new_points_xml)
  print("=== END New Points XML ===")
  
  -- Replace the points section in the original XML
  print("=== DEBUG: Replacing XML Points Section ===")
  local new_xml = xml_data:gsub("<Points>.-</Points>", 
    "<Points>\n" .. new_points_xml .. "      </Points>", 1)
  
  -- CRITICAL FIX: Double the Length field (envelope duration/resolution)
  local new_length = current_length * 2
  print(string.format("=== DEBUG: Doubling Length from %d to %d ===", current_length, new_length))
  new_xml = new_xml:gsub("<Length>.-</Length>", "<Length>" .. new_length .. "</Length>", 1)
  
  print("=== DEBUG: Final XML ===")
  print(new_xml)
  print("=== END Final XML ===")
  
  -- Inject the modified XML back to the device
  device.active_preset_data = new_xml
  
  renoise.app():show_status(string.format("✅ PakettiXMLizer: Doubled LFO resolution %d→%d points", point_count, new_point_count))
  print(string.format("PakettiXMLizer: Successfully doubled LFO resolution from %d to %d points", point_count, new_point_count))
end

-- Function to halve LFO envelope resolution by keeping every second point
function pakettiHalveLFOResolution()
  local device = renoise.song().selected_device
  
  -- Check if LFO device is selected
  if not device or not is_lfo_device(device) then
    renoise.app():show_status("PakettiXMLizer: Please select an LFO device first")
    print("PakettiXMLizer: Error - No LFO device selected")
    return
  end
  
  local xml_data = device.active_preset_data
  if not xml_data or xml_data == "" then
    renoise.app():show_status("PakettiXMLizer: No LFO preset data found")
    print("PakettiXMLizer: Error - No preset data in LFO device")
    return
  end
  
  print("=== DEBUG: Original XML Data ===")
  print(xml_data)
  print("=== END Original XML ===")
  
  -- Extract envelope length first
  local current_length = 4  -- default
  local length_match = xml_data:match("<Length>(%d+)</Length>")
  if length_match then
    current_length = tonumber(length_match)
  end
  print("=== DEBUG: Current envelope length: " .. current_length .. " ===")
  
  -- Extract all points within the current length range
  local points = {}
  local point_count = 0
  
  print("=== DEBUG: Extracting Points (within length range 0-" .. (current_length-1) .. ") ===")
  for point_line in xml_data:gmatch("<Point>([^<]+)</Point>") do
    print("Found point line: " .. point_line)
    local step, value, scaling = point_line:match("([^,]+),([^,]+),([^,]+)")
    if step and value and scaling then
      local step_num = tonumber(step)
      local point = {
        step = step_num,
        value = tonumber(value), 
        scaling = tonumber(scaling)
      }
      
      -- Only include points within the current length range
      if step_num < current_length then
        point_count = point_count + 1
        table.insert(points, point)
        print(string.format("Included point %d: step=%d, value=%g, scaling=%g", point_count, point.step, point.value, point.scaling))
      else
        print(string.format("Skipped point beyond length: step=%d (length=%d)", step_num, current_length))
      end
    else
      print("Failed to parse point: " .. point_line)
    end
  end
  print("=== END Extracting Points ===")
  
  if point_count == 0 then
    renoise.app():show_status("PakettiXMLizer: No envelope points found in LFO")
    print("PakettiXMLizer: Error - No envelope points found")
    return
  end
  
  if point_count < 2 then
    renoise.app():show_status("PakettiXMLizer: Need at least 2 points to halve resolution")
    print("PakettiXMLizer: Error - Need at least 2 points to halve")
    return
  end
  
  -- Keep only points at even step positions and renumber them
  local halved_points = {}
  local new_point_count = 0
  
  print("=== DEBUG: Creating Halved Points (keeping every second point) ===")
  for i, point in ipairs(points) do
    -- Keep only points where the original step position is even
    if point.step % 2 == 0 then
      new_point_count = new_point_count + 1
      local halved_point = {
        step = point.step / 2,  -- Halve the step position
        value = point.value,
        scaling = point.scaling
      }
      table.insert(halved_points, halved_point)
      print(string.format("Kept point at original step %d → new step %d, value=%g", point.step, halved_point.step, halved_point.value))
    else
      print(string.format("Skipped point at odd step %d, value=%g", point.step, point.value))
    end
  end
  print("=== END Creating Halved Points ===")
  
  if new_point_count == 0 then
    renoise.app():show_status("PakettiXMLizer: No even-step points found to keep")
    print("PakettiXMLizer: Error - No even-step points found")
    return
  end
  
  print(string.format("PakettiXMLizer: Halving LFO resolution from %d to %d points", point_count, new_point_count))
  
  -- Rebuild the points XML section
  print("=== DEBUG: Building New XML Points ===")
  local new_points_xml = ""
  for i, point in ipairs(halved_points) do
    local point_xml = string.format("        <Point>%d,%g,%g</Point>\n", 
      point.step, point.value, point.scaling)
    new_points_xml = new_points_xml .. point_xml
    print(string.format("Point %d XML: %s", i, point_xml:gsub("\n", "")))
  end
  print("=== Complete New Points XML ===")
  print(new_points_xml)
  print("=== END New Points XML ===")
  
  -- Replace the points section in the original XML
  print("=== DEBUG: Replacing XML Points Section ===")
  local new_xml = xml_data:gsub("<Points>.-</Points>", 
    "<Points>\n" .. new_points_xml .. "      </Points>", 1)
  
  -- CRITICAL: Halve the Length field (envelope duration/resolution)
  local new_length = math.floor(current_length / 2)
  if new_length < 1 then new_length = 1 end  -- Ensure minimum length of 1
  print(string.format("=== DEBUG: Halving Length from %d to %d ===", current_length, new_length))
  new_xml = new_xml:gsub("<Length>.-</Length>", "<Length>" .. new_length .. "</Length>", 1)
  
  print("=== DEBUG: Final XML ===")
  print(new_xml)
  print("=== END Final XML ===")
  
  -- Inject the modified XML back to the device
  device.active_preset_data = new_xml
  
  renoise.app():show_status(string.format("✅ PakettiXMLizer: Halved LFO resolution %d→%d points", point_count, new_point_count))
  print(string.format("PakettiXMLizer: Successfully halved LFO resolution from %d to %d points", point_count, new_point_count))
end

-- Register keybinding and menu entries for Double LFO Resolution
renoise.tool():add_keybinding{name="Global:Paketti:Double LFO Envelope Resolution", invoke=pakettiDoubleLFOResolution}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Double LFO Envelope Resolution", invoke=pakettiDoubleLFOResolution}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Custom LFO Envelopes:Double LFO Envelope Resolution", invoke=pakettiDoubleLFOResolution}

-- Register keybinding and menu entries for Halve LFO Resolution
renoise.tool():add_keybinding{name="Global:Paketti:Halve LFO Envelope Resolution", invoke=pakettiHalveLFOResolution}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Halve LFO Envelope Resolution", invoke=pakettiHalveLFOResolution}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Custom LFO Envelopes:Halve LFO Envelope Resolution", invoke=pakettiHalveLFOResolution}

-- Paketti LFO External Editor Toggle with Auto-Custom Mode
-- Toggle external editor visibility for selected device and force LFO to Custom mode
function pakettiToggleLFOExternalEditor()
  local song = renoise.song()
  local selected_device = song.selected_device
  
  -- Check if any device is selected
  if not selected_device then
    renoise.app():show_status("No device selected - please select a device with external editor support")
    print("-- Paketti LFO External Editor: No device selected")
    return
  end
  
  -- Get device information the Paketti way
  local device_path = selected_device.device_path
  print("-- Paketti LFO External Editor: Checking device:", device_path)
  
  -- Check if external editor is available
  if not selected_device.external_editor_available then
    renoise.app():show_status(string.format("Device '%s' does not support external editor", device_path))
    print("-- Paketti LFO External Editor: Device", device_path, "does not support external editor")
    return
  end
  
  -- Check current visibility state and toggle
  local current_state = selected_device.external_editor_visible
  local new_state = not current_state
  
  print("-- Paketti LFO External Editor: Current state:", current_state, "→ New state:", new_state)
  
  -- Special handling for LFO devices - force to Custom mode when opening external editor
  if device_path:find("LFO") and new_state then
    print("-- Paketti LFO External Editor: LFO device detected, forcing to Custom mode")
    
    -- Get current XML data
    local current_xml = selected_device.active_preset_data
    if current_xml and current_xml ~= "" then
      -- Modify existing XML to set Type to 4 (Custom) while preserving everything else
      local modified_xml = current_xml:gsub("<Type>%s*<Value>%d+</Value>%s*</Type>", "<Type>\n      <Value>4</Value>\n    </Type>")
      selected_device.active_preset_data = modified_xml
      print("-- Paketti LFO External Editor: Forced existing LFO to Custom mode (Type 4)")
    else
      print("-- Paketti LFO External Editor: No existing preset data, LFO probably already in Custom mode")
    end
  end
  
  -- Apply the toggle
  selected_device.external_editor_visible = new_state
  
  -- Provide user feedback
  local state_text = new_state and "OPENED" or "CLOSED"
  local status_message = string.format("External editor %s for '%s'", state_text, device_path)
  
  renoise.app():show_status(status_message)
  print("-- Paketti LFO External Editor:", status_message)
  
  -- Special handling for LFO devices
  if device_path:find("LFO") then
    print("-- Paketti LFO External Editor: LFO device detected, external editor", state_text:lower())
    if new_state then
      renoise.app():show_status("LFO external editor opened - edit Custom envelope curves and modulation settings")
    else
      renoise.app():show_status("LFO external editor closed")
    end
  end
end

-- Advanced function to check and report all devices with external editor support
function pakettiListDevicesWithExternalEditor()
  local song = renoise.song()
  local devices_with_editor = {}
  local total_devices = 0
  
  -- Check all tracks for devices
  for track_index, track in ipairs(song.tracks) do
    for device_index, device in ipairs(track.devices) do
      total_devices = total_devices + 1
      if device.external_editor_available then
        table.insert(devices_with_editor, {
          track = track_index,
          device = device_index,
          path = device.device_path,
          visible = device.external_editor_visible
        })
      end
    end
  end
  
  print("-- Paketti LFO External Editor: Scanned", total_devices, "devices")
  print("-- Paketti LFO External Editor: Found", #devices_with_editor, "devices with external editor support:")
  
  if #devices_with_editor == 0 then
    renoise.app():show_status("No devices with external editor support found in current song")
    return
  end
  
  for _, dev_info in ipairs(devices_with_editor) do
    local status = dev_info.visible and "OPEN" or "CLOSED"
    print(string.format("-- Track %02d Device %02d: %s - %s", 
      dev_info.track, dev_info.device, dev_info.path, status))
  end
  
  renoise.app():show_status(string.format("Found %d devices with external editor support (see console for details)", #devices_with_editor))
end

-- Menu entries
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Device:Toggle LFO/Device External Editor", invoke = pakettiToggleLFOExternalEditor}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Device:List Devices with External Editor Support", invoke = pakettiListDevicesWithExternalEditor}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Toggle LFO/Device External Editor", invoke = pakettiToggleLFOExternalEditor}

-- Keybindings  
renoise.tool():add_keybinding{name = "Global:Paketti:Toggle LFO/Device External Editor", invoke = pakettiToggleLFOExternalEditor}
renoise.tool():add_keybinding{name = "Global:Paketti:List Devices with External Editor Support", invoke = pakettiListDevicesWithExternalEditor}

-- MIDI mappings
renoise.tool():add_midi_mapping{name = "Paketti:Toggle LFO/Device External Editor", invoke = function(message) 
  if message:is_trigger() then 
    pakettiToggleLFOExternalEditor() 
  end 
end}

renoise.tool():add_midi_mapping{name = "Paketti:List Devices with External Editor Support", invoke = function(message) 
  if message:is_trigger() then 
    pakettiListDevicesWithExternalEditor() 
  end 
end}

-- Quick LFO Custom Editor - Load LFO, set to Custom, open external editor
-- Toggle functionality: shows/hides external editor if LFO in custom mode is selected
-- Full loadnative compatibility: handles both track devices and sample FX chains
function pakettiQuickLFOCustomEditor()
  local song = renoise.song()
  local window = renoise.app().window
  local effect = "Audio/Effects/Native/*LFO"
  
  print("-- Paketti Quick LFO Custom Editor: Starting...")
  
  -- Handle middle frame switching (same as loadnative)
  if window.active_middle_frame == 6 then
    window.active_middle_frame = 7
  end
  
  -- Check if currently selected device is an LFO in custom mode
  local current_device = nil
  local is_sample_fx = false
  
  if window.active_middle_frame == 7 then
    -- Sample FX Chain mode
    local chain = song.selected_sample_device_chain
    if chain and chain.devices[song.selected_sample_device_index] then
      current_device = chain.devices[song.selected_sample_device_index]
      is_sample_fx = true
    end
  else
    -- Track device mode
    local selected_track = song.selected_track
    if selected_track.devices[song.selected_device_index] then
      current_device = selected_track.devices[song.selected_device_index]
      is_sample_fx = false
    end
  end
  
  -- Check if current device is LFO in custom mode
  if current_device and current_device.device_path == "Audio/Effects/Native/*LFO" then
    local is_custom_mode = current_device.parameters[7].value == 4
    
    if is_custom_mode then
      -- Toggle external editor visibility
      if current_device.external_editor_available then
        local was_visible = current_device.external_editor_visible
        current_device.external_editor_visible = not was_visible
        
        if current_device.external_editor_visible then
          print("-- Paketti Quick LFO Custom Editor: Showed external editor for existing LFO")
          renoise.app():show_status("Quick LFO Custom Editor: Showed external editor")
        else
          print("-- Paketti Quick LFO Custom Editor: Hid external editor for existing LFO")
          renoise.app():show_status("Quick LFO Custom Editor: Hid external editor")
        end
        return
      else
        print("-- Paketti Quick LFO Custom Editor: External editor not available for current LFO")
        renoise.app():show_status("Quick LFO Custom Editor: External editor not available")
        return
      end
    else
      -- LFO is selected but not in custom mode - set to custom and show editor
      print("-- Paketti Quick LFO Custom Editor: LFO selected but not in custom mode, setting to custom")
      current_device.parameters[7].value = 4
      
      if current_device.external_editor_available then
        current_device.external_editor_visible = true
        print("-- Paketti Quick LFO Custom Editor: Set existing LFO to custom mode and opened external editor")
        renoise.app():show_status("Quick LFO Custom Editor: Set to custom mode, opened external editor")
      else
        print("-- Paketti Quick LFO Custom Editor: Set to custom mode (external editor not available)")
        renoise.app():show_status("Quick LFO Custom Editor: Set to custom mode (external editor not available)")
      end
      return
    end
  end
  
  -- No LFO device selected or current device is not LFO - create new LFO
  print("-- Paketti Quick LFO Custom Editor: No LFO selected, creating new LFO device")
  
  local lfo_device = nil
  local checkline = nil
  
  -- Sample FX Chain loading (same logic as loadnative)
  if window.active_middle_frame == 7 then
    print("-- Paketti Quick LFO Custom Editor: Sample FX Chain mode detected")
    
    local chain = song.selected_sample_device_chain
    local chain_index = song.selected_sample_device_chain_index
    
    if chain == nil or chain_index == 0 then
      song.selected_instrument:insert_sample_device_chain_at(1)
      chain = song.selected_sample_device_chain
      chain_index = 1
    end
    
    if chain then
      local sample_devices = chain.devices
      if preferences.pakettiLoadOrder.value then
        -- Load at end of chain
        checkline = #sample_devices + 1
      else
        -- Load at start (after input device if present)
        checkline = (table.count(sample_devices)) < 2 and 2 or (sample_devices[2] and sample_devices[2].name == "#Line Input" and 3 or 2)
      end
      checkline = math.min(checkline, #sample_devices + 1)
      
      print("-- Paketti Quick LFO Custom Editor: Loading LFO to sample FX chain at position", checkline)
      
      -- Insert LFO device into sample FX chain
      chain:insert_device_at(effect, checkline)
      sample_devices = chain.devices
      
      if sample_devices[checkline] then
        lfo_device = sample_devices[checkline]
        song.selected_sample_device_index = checkline
        
        local instrument_name = song.selected_instrument.name
        local chain_name = chain.name
        print("-- Paketti Quick LFO Custom Editor: Loaded LFO to", instrument_name, "FX Chain:", chain_name)
      end
    else
      renoise.app():show_status("No sample selected.")
      return
    end
    
  else
    -- Track device loading (original logic)
    print("-- Paketti Quick LFO Custom Editor: Track device mode detected")
    
    local selected_track = song.selected_track
    local devices = selected_track.devices
    
    if preferences.pakettiLoadOrder.value then
      -- Load at end of track devices
      checkline = #devices + 1
    else
      -- Load at start (after input device if present, after line input if present)
      checkline = (table.count(devices)) < 2 and 2 or (devices[2] and devices[2].name == "#Line Input" and 3 or 2)
    end
    checkline = math.min(checkline, #devices + 1)
    
    print("-- Paketti Quick LFO Custom Editor: Loading LFO to track at position", checkline)
    
    -- Insert LFO device to track
    selected_track:insert_device_at(effect, checkline)
    song.selected_device_index = checkline
    lfo_device = selected_track.devices[checkline]
    
    -- Show mixer frame for device control
    window.lower_frame_is_visible = true
    window.active_lower_frame = 1
  end
  
  -- Verify LFO device loaded successfully
  if not lfo_device or lfo_device.device_path ~= "Audio/Effects/Native/*LFO" then
    renoise.app():show_status("Failed to load LFO device")
    print("-- Paketti Quick LFO Custom Editor: Error - Failed to load LFO device")
    return
  end
  
  print("-- Paketti Quick LFO Custom Editor: LFO device loaded successfully")
  
  -- Step 3: Set LFO to Custom mode (parameter 7, value 4)
  lfo_device.parameters[7].value = 4
  print("-- Paketti Quick LFO Custom Editor: Set LFO to Custom mode")
  
  -- Step 4: Open external editor
  if lfo_device.external_editor_available then
    lfo_device.external_editor_visible = true
    print("-- Paketti Quick LFO Custom Editor: Opened external editor")
    renoise.app():show_status("Quick LFO Custom Editor: Loaded LFO, set to Custom mode, opened external editor")
  else
    print("-- Paketti Quick LFO Custom Editor: Warning - External editor not available")
    renoise.app():show_status("Quick LFO Custom Editor: LFO loaded and set to Custom mode (external editor not available)")
  end
  
  print("-- Paketti Quick LFO Custom Editor: Complete!")
end

-- Register the unified function
renoise.tool():add_keybinding{name = "Global:Paketti:Quick LFO Custom Editor", invoke = pakettiQuickLFOCustomEditor}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Device:Quick LFO Custom Editor", invoke = pakettiQuickLFOCustomEditor}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Quick LFO Custom Editor", invoke = pakettiQuickLFOCustomEditor}
renoise.tool():add_midi_mapping{name = "Paketti:Quick LFO Custom Editor", invoke = function(message) 
  if message:is_trigger() then 
    pakettiQuickLFOCustomEditor() 
  end 
end}

