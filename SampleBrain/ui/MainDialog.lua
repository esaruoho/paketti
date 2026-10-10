-- SampleBrain/ui/MainDialog.lua
-- Native Renoise ViewBuilder Dialog for SampleBrain

local SampleReader = require("SampleBrain.renoise.SampleReader")
local SampleWriter = require("SampleBrain.renoise.SampleWriter")
local BlockGenerator = require("SampleBrain.analysis.BlockGenerator")
local SynapseBuilder = require("SampleBrain.analysis.SynapseBuilder")
local Renderer = require("SampleBrain.render.Renderer")
local SourceRef = require("SampleBrain.model.SourceRef")
local JobRunner = require("SampleBrain.jobs.JobRunner")
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
local brain_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN, channel_mode = Constants.CHANNEL_MIX }
local target_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN, channel_mode = Constants.CHANNEL_MIX }

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

local function update_job_ui(is_running)
  if vb and vb.views.btn_cancel then
    vb.views.btn_cancel.visible = is_running
  end
end

function MainDialog.show()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()

  local content = vb:column{
    margin = 10,
    spacing = 8,

    -- Title & Global Job Status
    vb:row{
      vb:text{ text = "SAMPLEBRAIN FOR RENOISE", font = "bold", style = "strong" },
      vb:space{ width = 20 },
      vb:button{
        id = "btn_cancel",
        text = "Cancel Job",
        visible = false,
        notifier = function()
          if JobRunner.is_running() then
            JobRunner.cancel()
            vb.views.job_status.text = "Job cancelled."
            update_job_ui(false)
          end
        end
      },
      vb:text{ id = "job_status", text = "", style = "italic" }
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
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) target_settings.window_type = v end },
          vb:text{ text = "Channel:" },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, notifier = function(v) target_settings.channel_mode = v end }
        },
        vb:row{
          vb:button{
            text = "Set Current Sample as Target", width = 180,
            notifier = function()
              if JobRunner.is_running() then return end
              local smp = renoise.song().selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                JobRunner.start(
                  function(job)
                    local pcm, rate = SampleReader.read_channel(smp, target_settings.channel_mode)
                    if not pcm then error("Failed to read sample") end
                    target_source = SourceRef.create(9999, smp.name, pcm, rate)
                    target_blocks = BlockGenerator.generate(target_source, target_settings.block_size, target_settings.overlap, target_settings.window_type, 1, job)
                    return { smp_name = smp.name, block_count = #target_blocks }
                  end,
                  function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                  function(res)
                    vb.views.target_status.text = string.format("Target: %s (%d blocks)", res.smp_name ~= "" and res.smp_name or "Untitled", res.block_count)
                    vb.views.job_status.text = ""
                    update_job_ui(false)
                  end,
                  function(err)
                    vb.views.job_status.text = "Target analysis failed."
                    update_job_ui(false)
                    renoise.app():show_error("Target analysis failed: " .. tostring(err))
                  end
                )
                update_job_ui(true)
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
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) brain_settings.window_type = v end },
          vb:text{ text = "Channel:" },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, notifier = function(v) brain_settings.channel_mode = v end }
        },
        vb:row{
          spacing = 6,
          vb:button{
            text = "Add Current Sample to Brain", width = 180,
            notifier = function()
              if JobRunner.is_running() then return end
              local smp = renoise.song().selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                JobRunner.start(
                  function(job)
                    local pcm, rate = SampleReader.read_channel(smp, brain_settings.channel_mode)
                    if not pcm then error("Failed to read sample") end
                    
                    local src_id = #brain_sources + 1
                    local ref = SourceRef.create(src_id, smp.name, pcm, rate)
                    brain_sources[src_id] = ref
                    
                    local start_id = #brain_blocks + 1
                    local blocks = BlockGenerator.generate(ref, brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, start_id, job)
                    for _, b in ipairs(blocks) do
                      brain_blocks[#brain_blocks + 1] = b
                    end
                    synapses_built = false
                  end,
                  function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                  function()
                    vb.views.brain_status.text = string.format("Brain: %d samples, %d total blocks", #brain_sources, #brain_blocks)
                    vb.views.job_status.text = ""
                    update_job_ui(false)
                  end,
                  function(err)
                    vb.views.job_status.text = "Brain analysis failed."
                    update_job_ui(false)
                    renoise.app():show_error("Brain analysis failed: " .. tostring(err))
                  end
                )
                update_job_ui(true)
              else
                renoise.app():show_warning("Selected sample has no audio data.")
              end
            end
          },
          vb:button{
            text = "Clear Brain", width = 90,
            notifier = function()
              if JobRunner.is_running() then return end
              brain_sources = {}
              brain_blocks = {}
              synapses_built = false
              vb.views.brain_status.text = "Brain: Empty"
            end
          },
          vb:button{
            text = "Grow Synapses", width = 110,
            notifier = function()
              if JobRunner.is_running() then return end
              if #brain_blocks == 0 then return end
              
              JobRunner.start(
                function(job)
                  return SynapseBuilder.build_fixed(brain_blocks, num_synapses, ratio, n_ratio, fft_start, fft_end, job)
                end,
                function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                function(count)
                  synapses_built = true
                  vb.views.brain_status.text = string.format("Brain: %d blocks, %d synapses grown!", #brain_blocks, count)
                  vb.views.job_status.text = ""
                  update_job_ui(false)
                  renoise.app():show_status("SampleBrain: Synapses generated.")
                end,
                function(err)
                  vb.views.job_status.text = "Synapse generation failed."
                  update_job_ui(false)
                  renoise.app():show_error("Synapse generation failed: " .. tostring(err))
                end
              )
              update_job_ui(true)
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
          vb:valuebox{ min = 0.0, max = 1.0, value = target_mix, step = 0.1, notifier = function(v) target_mix = v end },
          vb:text{ text = "Slide Err:" },
          vb:valuebox{ min = 0.1, max = 500.0, value = slide_error, step = 1.0, notifier = function(v) slide_error = v end }
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
          if JobRunner.is_running() then return end
          if #target_blocks == 0 or #brain_blocks == 0 then
            renoise.app():show_warning("Need both Target and Brain samples.")
            return
          end

          JobRunner.start(
            function(job)
              if (algo == Constants.ALGO_SYNAPTIC or algo == Constants.ALGO_SYNAPTIC_SLIDE) and not synapses_built then
                SynapseBuilder.build_fixed(brain_blocks, num_synapses, ratio, n_ratio, fft_start, fft_end, job)
                synapses_built = true
              end

              local options = {
                block_size = target_settings.block_size,
                overlap = target_settings.overlap,
                window_type = target_settings.window_type,
                ratio = ratio, n_ratio = n_ratio,
                fft_start = fft_start, fft_end = fft_end,
                usage_importance = usage_importance,
                usage_falloff = usage_falloff,
                stickiness = stickiness,
                slide_error = slide_error,
                algo = algo,
                stretch = stretch,
                autotune = autotune,
                n_mix = n_mix,
                target_mix = target_mix,
                num_synapses = num_synapses,
                brain_gain = brain_gain,
                job = job
              }

              return Renderer.render(brain_blocks, target_blocks, options)
            end,
            function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
            function(out_pcm)
              SampleWriter.write_new_instrument(out_pcm, nil, Constants.DEFAULT_SAMPLE_RATE, "SampleBrain")
              vb.views.job_status.text = string.format("Rendered %d frames.", #out_pcm)
              update_job_ui(false)
              renoise.app():show_status("SampleBrain render complete!")
              if synapses_built then
                 vb.views.brain_status.text = string.format("Brain: %d blocks (Auto-synapses grown)", #brain_blocks)
              end
            end,
            function(err)
              vb.views.job_status.text = "Rendering failed."
              update_job_ui(false)
              renoise.app():show_error("Render failed: " .. tostring(err))
            end
          )
          update_job_ui(true)
        end
      }
    }
  }

  dialog = renoise.app():show_custom_dialog("SampleBrain for Renoise", content)
end

return MainDialog
