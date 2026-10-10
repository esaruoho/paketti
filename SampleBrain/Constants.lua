-- SampleBrain/Constants.lua
-- Configuration defaults and constants matching C++ reference implementation

local Constants = {}

-- Block Defaults
Constants.DEFAULT_BLOCK_SIZE = 1024
Constants.DEFAULT_OVERLAP = 0.5 -- 50% overlap (hop = size / 2)
Constants.DEFAULT_SAMPLE_RATE = 44100

-- Analysis Defaults
Constants.MFCC_FILTERS = 12
Constants.FFT_BINS_CROPPED = 100
Constants.FFT_BIAS = 200.0

-- Matching Defaults
Constants.DEFAULT_RATIO = 0.5            -- 0.0 = FFT only, 1.0 = MFCC only, 0.5 = 50/50 mix
Constants.DEFAULT_N_RATIO = 0.5          -- 0.0 = raw only, 1.0 = normalized only
Constants.DEFAULT_USAGE_IMPORTANCE = 0.0 -- 0.0 = ignore usage, >0.0 = novelty/boredom penalty
Constants.DEFAULT_STICKINESS = 0.0       -- 0.0 = no stickiness, 1.0 = max stickiness
Constants.DEFAULT_SLIDE_ERROR = 1.0      -- Threshold error for Synaptic Slide
Constants.DEFAULT_NUM_SYNAPSES = 100     -- Number of synapses per block in similarity graph
Constants.USAGE_FACTOR = 1000.0          -- Usage increment upon selection
Constants.USAGE_FALLOFF = 0.9            -- Usage decay per search step

-- Search Algorithms
Constants.ALGO_BASIC = 1
Constants.ALGO_REVERSED = 2
Constants.ALGO_SYNAPTIC = 3
Constants.ALGO_SYNAPTIC_SLIDE = 4

-- Channel Modes
Constants.CHANNEL_MIX = 1
Constants.CHANNEL_LEFT = 2
Constants.CHANNEL_RIGHT = 3

-- Windowing Types
Constants.WINDOW_RECTANGLE = 1
Constants.WINDOW_HANN = 2
Constants.WINDOW_HAMMING = 3
Constants.WINDOW_BLACKMAN = 4
Constants.WINDOW_BARTLETT = 5
Constants.WINDOW_GAUSSIAN = 6
Constants.WINDOW_FLAT_TOP = 7
Constants.WINDOW_DODGY = 8

return Constants
