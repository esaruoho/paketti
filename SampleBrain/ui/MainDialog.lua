-- SampleBrain/ui/MainDialog.lua
-- Native Renoise ViewBuilder Dialog for SampleBrain

local SampleReader = require("SampleBrain.renoise.SampleReader")
local SampleWriter = require("SampleBrain.renoise.SampleWriter")
local BlockGenerator = require("SampleBrain.analysis.BlockGenerator")
local SynapseBuilder = require("SampleBrain.analysis.SynapseBuilder")
local Renderer = require("SampleBrain.render.Renderer")
local SourceRef = require("SampleBrain.model.SourceRef")
local Constants = require("SampleBrain.Constants")

local MainDialog = {}

local dialog = nil
local vb = nil

-- Dialog state
local brain_sources = {}
local brain_blocks = {}

local target_source = nil
local target_blocks = {}

-- Separate Analysis Settings
local brain_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN }
local target_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN }

-- Matching Settings
local ratio = Constants.DEFAULT_RATIO
local n_ratio = Constants.DEFAULT_N_RATIO
local fft_start = 1
local fft_end = Constants.FFT_BINS_CROPPED
local usage_importance = Constants.DEFAULT_USAGE_IMPORTANCE
local usage_falloff = Constants.USAGE_FALLOFF
local stickiness = Constants.DEFAULT_STICKINESS
local algo = Constants.ALGO_BASIC
local stretch = 1
local slide_error = Constants.DEFAULT_SLIDE_ERROR
local num_synapses = Constants.DEFAULT_NUM_SYNAPSES
local synapses_built = false

-- Render Settings
local autotune = 0.0
local n_mix = 0.0
local target_mix = 0.0
local brain_gain = 1.0

function MainDialog.show()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()

  local content = vb:column{
    margin = 10,
    spacing = 8,

    -- Title
    vb:row{
      vb:text{ text = "SAMPLEBRAIN FOR RENOISE", font = "bold", style = "strong" }
    },

    -- Target Section
    vb:group{
      width = "100%", style = "panel",
      vb:column{
        margin = 6, spacing = 4,
        vb:row{ vb:text{ text = "Target Audio", font = "bold" } },
        vb:row{
          spacing = 6,
          vb:text{ text = "Block:" },
          vb:popup{ items = { "512", "1024", "2048", "4096" }, value = 2, notifier = function(v) target_settings.block_size = ({512,1024,2048,4096})[v] end },
          vb:text{ text = "Overlap:" },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, notifier = function(v) target_settings.overlap = ({0.25,0.5,0.75})[v] end },
          vb:text{ text = "Window:" },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) target_settings.window_type = v end }
        },
        vb:row{
          vb:button{
            text = "Set Current Sample as Target", width = 180,
            notifier = function()
              local smp = renoise.song().selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                local pcm, rate = SampleReader.read_mono(smp)
                if pcm then
                  target_source = SourceRef.create(9999, smp.name, pcm, rate)
                  target_blocks = BlockGenerator.generate(target_source, target_settings.block_size, target_settings.overlap, target_settings.window_type, 1)
                  vb.views.target_status.text = string.format("Target: %s (%d blocks)", smp.name ~= "" and smp.name or "Untitled", #target_blocks)
                end
              else
                renoise.app():show_warning("Selected sample has no audio data.")
              end
            end
          },
          vb:text{ id = "target_status", text = "Target: None selected", style = "italic" }
        }
      }
    },

    -- Brain Section
    vb:group{
      width = "100%", style = "panel",
      vb:column{
        margin = 6, spacing = 4,
        vb:row{ vb:text{ text = "Brain Sources", font = "bold" } },
        vb:row{
          spacing = 6,
          vb:text{ text = "Block:" },
          vb:popup{ items = { "512", "1024", "2048", "4096" }, value = 2, notifier = function(v) brain_settings.block_size = ({512,1024,2048,4096})[v] end },
          vb:text{ text = "Overlap:" },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, notifier = function(v) brain_settings.overlap = ({0.25,0.5,0.75})[v] end },
          vb:text{ text = "Window:" },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) brain_settings.window_type = v end }
        },
        vb:row{
          spacing = 6,
          vb:button{
            text = "Add Current Sample to Brain", width = 180,
            notifier = function()
              local smp = renoise.song().selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                local pcm, rate = SampleReader.read_mono(smp)
                if pcm then
                  local src_id = #brain_sources + 1
                  local ref = SourceRef.create(src_id, smp.name, pcm, rate)
                  brain_sources[src_id] = ref
                  
                  local start_id = #brain_blocks + 1
                  local blocks = BlockGenerator.generate(ref, brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, start_id)
                  for _, b in ipairs(blocks) do
                    brain_blocks[#brain_blocks + 1] = b
                  end
                  
                  synapses_built = false
                  vb.views.brain_status.text = string.format("Brain: %d samples, %d total blocks", #brain_sources, #brain_blocks)
                end
              end
            end
          },
          vb:button{
            text = "Clear Brain", width = 90,
            notifier = function()
              brain_sources = {}
              brain_blocks = {}
              synapses_built = false
              vb.views.brain_status.text = "Brain: Empty"
            end
          },
          vb:button{
            text = "Grow Synapses", width = 110,
            notifier = function()
              if #brain_blocks == 0 then return end
              local count = SynapseBuilder.build_fixed(brain_blocks, 1000, ratio, n_ratio, fft_start, fft_end)
              synapses_built = true
              vb.views.brain_status.text = string.format("Brain: %d blocks, %d synapses grown!", #brain_blocks, count)
              renoise.app():show_status("SampleBrain: Synapses generated.")
            end
          }
        },
        vb:row{ vb:text{ id = "brain_status", text = "Brain: Empty", style = "italic" } }
      }
    },

    -- Match & Output Params
    vb:group{
      width = "100%", style = "panel",
      vb:column{
        margin = 6, spacing = 6,
        vb:text{ text = "Match & Render Settings", font = "bold" },
        vb:row{
          spacing = 6,
          vb:text{ text = "Algo:" },
          vb:popup{ items = { "Basic", "Reversed", "Synaptic", "Synaptic Slide" }, value = algo, notifier = function(v) algo = v end },
          vb:text{ text = "FFT Start Bin:" },
          vb:valuebox{ min = 1, max = 100, value = fft_start, step = 1, notifier = function(v) fft_start = v end },
          vb:text{ text = "FFT End Bin:" },
          vb:valuebox{ min = 1, max = 100, value = fft_end, step = 1, notifier = function(v) fft_end = v end }
        },
        vb:row{
          spacing = 6,
          vb:text{ text = "FFT/MFCC Ratio:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = ratio, step = 0.1, notifier = function(v) ratio = v end },
          vb:text{ text = "Raw/Norm Ratio:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = n_ratio, step = 0.1, notifier = function(v) n_ratio = v end },
          vb:text{ text = "Stickiness:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = stickiness, step = 0.05, notifier = function(v) stickiness = v end }
        },
        vb:row{
          spacing = 6,
          vb:text{ text = "Novelty:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = usage_importance, step = 0.05, notifier = function(v) usage_importance = v end },
          vb:text{ text = "Boredom:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = usage_falloff, step = 0.05, notifier = function(v) usage_falloff = v end },
          vb:text{ text = "Stretch:" },
          vb:valuebox{ min = 1, max = 8, value = stretch, step = 1, notifier = function(v) stretch = v end }
        },
        vb:row{
          spacing = 6,
          vb:text{ text = "Autotune:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = autotune, step = 0.1, notifier = function(v) autotune = v end },
          vb:text{ text = "Norm Mix:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = n_mix, step = 0.1, notifier = function(v) n_mix = v end },
          vb:text{ text = "Target Mix:" },
          vb:valuebox{ min = 0.0, max = 1.0, value = target_mix, step = 0.1, notifier = function(v) target_mix = v end }
        }
      }
    },

    -- Render Action
    vb:row{
      spacing = 10,
      vb:button{
        text = "Render SampleBrain Output",
        width = 200, height = 30,
        notifier = function()
          if #target_blocks == 0 or #brain_blocks == 0 then
            renoise.app():show_warning("Need both Target and Brain samples.")
            return
          end

          vb.views.render_status.text = "Rendering..."

          local options = {
            block_size = target_settings.block_size,
            overlap = target_settings.overlap,
            window_type = target_settings.window_type,
            ratio = ratio, n_ratio = n_ratio,
            fft_start = fft_start, fft_end = fft_end,
            usage_importance = usage_importance,
            usage_falloff = usage_falloff,
            stickiness = stickiness,
            algo = algo,
            stretch = stretch,
            autotune = autotune,
            n_mix = n_mix,
            target_mix = target_mix,
            num_synapses = num_synapses,
            brain_gain = brain_gain
          }

          local out_pcm = Renderer.render(brain_blocks, target_blocks, options)
          SampleWriter.write_new_instrument(out_pcm, Constants.DEFAULT_SAMPLE_RATE, "SampleBrain")

          vb.views.render_status.text = string.format("Rendered %d frames.", #out_pcm)
          renoise.app():show_status("SampleBrain render complete!")
        end
      },
      vb:text{ id = "render_status", text = "Ready.", style = "italic" }
    }
  }

  dialog = renoise.app():show_custom_dialog("SampleBrain for Renoise", content)
end

return MainDialog
