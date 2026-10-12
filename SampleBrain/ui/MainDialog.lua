-- SampleBrain/ui/MainDialog.lua
-- Native Renoise ViewBuilder Dialog for SampleBrain

local SampleReader = require("SampleBrain.renoise.SampleReader")
local SampleWriter = require("SampleBrain.renoise.SampleWriter")
local BlockGenerator = require("SampleBrain.analysis.BlockGenerator")
local SynapseBuilder = require("SampleBrain.analysis.SynapseBuilder")
local Renderer = require("SampleBrain.render.Renderer")
local SourceRef = require("SampleBrain.model.SourceRef")
local JobRunner = require("SampleBrain.jobs.JobRunner")
local Session = require("SampleBrain.persistence.Session")
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
local brain_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN, channel_mode = Constants.CHANNEL_MIX, use_selection = false }
local target_settings = { block_size = 1024, overlap = 0.5, window_type = Constants.WINDOW_HANN, channel_mode = Constants.CHANNEL_MIX, use_selection = false }

local target_blocks_signature = ""
local synapses_signature = ""
local brain_settings_signature = ""

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
local normalize_output = false

local function update_job_ui(is_running)
  if vb and vb.views.btn_cancel then
    vb.views.btn_cancel.visible = is_running
  end
end

function MainDialog.reset_state()
  JobRunner.cancel()
  brain_sources = {}
  brain_blocks = {}
  target_source = nil
  target_blocks = {}
  target_blocks_signature = ""
  synapses_signature = ""
  brain_settings_signature = ""
  synapses_built = false
  if vb and vb.views.brain_status then
    vb.views.brain_status.text = "Brain: Empty"
  end
  if vb and vb.views.target_status then
    vb.views.target_status.text = "Target: None selected"
  end
  if vb and vb.views.job_status then
    vb.views.job_status.text = "Reset on new document."
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
          vb:popup{ items = { "256", "500", "512", "768", "1000", "1024", "1500", "2048", "3000", "4096" }, value = 6, notifier = function(v) target_settings.block_size = ({256,500,512,768,1000,1024,1500,2048,3000,4096})[v] end },
          vb:text{ text = "Overlap:" },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, notifier = function(v) target_settings.overlap = ({0.25,0.5,0.75})[v] end },
          vb:text{ text = "Window:" },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) target_settings.window_type = v end },
          vb:text{ text = "Channel:" },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, notifier = function(v) target_settings.channel_mode = v end },
          vb:checkbox{ value = target_settings.use_selection, notifier = function(v) target_settings.use_selection = v end },
          vb:text{ text = "Selection Only" }
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
                    local pcm, rate = SampleReader.read_channel(smp, target_settings.channel_mode, target_settings.use_selection)
                    if not pcm then error("Failed to read sample") end
                    
                    local temp_target_source = SourceRef.create(9999, smp.name, pcm, rate, smp)
                    local temp_target_blocks = BlockGenerator.generate(temp_target_source, target_settings.block_size, target_settings.overlap, target_settings.window_type, 1, job)
                    return { temp_source = temp_target_source, temp_blocks = temp_target_blocks, smp_name = smp.name, block_count = #temp_target_blocks }
                  end,
                  function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                  function(res)
                    target_source = res.temp_source
                    target_blocks = res.temp_blocks
                    target_blocks_signature = string.format("%d_%f_%d_%d_%s", target_settings.block_size, target_settings.overlap, target_settings.window_type, target_settings.channel_mode, tostring(target_settings.use_selection))
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
          vb:popup{ items = { "256", "500", "512", "768", "1000", "1024", "1500", "2048", "3000", "4096" }, value = 6, notifier = function(v) brain_settings.block_size = ({256,500,512,768,1000,1024,1500,2048,3000,4096})[v] end },
          vb:text{ text = "Overlap:" },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, notifier = function(v) brain_settings.overlap = ({0.25,0.5,0.75})[v] end },
          vb:text{ text = "Window:" },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, notifier = function(v) brain_settings.window_type = v end },
          vb:text{ text = "Channel:" },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, notifier = function(v) brain_settings.channel_mode = v end },
          vb:checkbox{ value = brain_settings.use_selection, notifier = function(v) brain_settings.use_selection = v end },
          vb:text{ text = "Selection Only" }
        },
        vb:row{
          spacing = 6,
          vb:button{
            text = "Add Current Sample", width = 130,
            notifier = function()
              local song = renoise.song()
              local inst = song.selected_instrument
              local smp = song.selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                local inst_idx = song.selected_instrument_index
                local smp_idx = song.selected_sample_index
                local pcm, rate = SampleReader.read_channel(smp, brain_settings.channel_mode, brain_settings.use_selection)
                if not pcm then 
                  renoise.app():show_warning("Failed to read sample") 
                  return
                end
                
                -- Capture exact start/end based on selection mode
                local s_start, s_end = 1, smp.sample_buffer.number_of_frames
                if brain_settings.use_selection and smp.sample_buffer.selection_start > 0 and smp.sample_buffer.selection_end > 0 then
                  s_start = smp.sample_buffer.selection_start
                  s_end = smp.sample_buffer.selection_end
                end

                local src_id = #brain_sources + 1
                local ref = SourceRef.create(src_id, smp.name, pcm, rate, inst_idx, smp_idx, s_start, s_end)
                brain_sources[src_id] = ref
                
                brain_settings_signature = ""
                vb.views.brain_status.text = string.format("Brain: %d sources, %d blocks (STALE)", #brain_sources, #brain_blocks)
              else
                renoise.app():show_warning("Selected sample has no audio data.")
              end
            end
          },
          vb:button{
            text = "Add Instrument Samples", width = 140,
            notifier = function()
              local song = renoise.song()
              local inst = song.selected_instrument
              if not inst then return end
              local inst_idx = song.selected_instrument_index
              local count = 0
              for smp_idx, smp in ipairs(inst.samples) do
                if smp.sample_buffer and smp.sample_buffer.has_sample_data then
                  local pcm, rate = SampleReader.read_channel(smp, brain_settings.channel_mode, brain_settings.use_selection)
                  if pcm then
                    local s_start, s_end = 1, smp.sample_buffer.number_of_frames
                    if brain_settings.use_selection and smp.sample_buffer.selection_start > 0 and smp.sample_buffer.selection_end > 0 then
                      s_start = smp.sample_buffer.selection_start
                      s_end = smp.sample_buffer.selection_end
                    end

                    local src_id = #brain_sources + 1
                    brain_sources[src_id] = SourceRef.create(src_id, smp.name, pcm, rate, inst_idx, smp_idx, s_start, s_end)
                    count = count + 1
                  end
                end
              end
              brain_settings_signature = ""
              vb.views.brain_status.text = string.format("Brain: %d sources (+%d), %d blocks (STALE)", #brain_sources, count, #brain_blocks)
            end
          },
          vb:button{
            text = "Add All Song Samples", width = 140,
            notifier = function()
              local song = renoise.song()
              local count = 0
              for inst_idx, inst in ipairs(song.instruments) do
                for smp_idx, smp in ipairs(inst.samples) do
                  if smp.sample_buffer and smp.sample_buffer.has_sample_data then
                    local pcm, rate = SampleReader.read_channel(smp, brain_settings.channel_mode, brain_settings.use_selection)
                    if pcm then
                      local s_start, s_end = 1, smp.sample_buffer.number_of_frames
                      if brain_settings.use_selection and smp.sample_buffer.selection_start > 0 and smp.sample_buffer.selection_end > 0 then
                        s_start = smp.sample_buffer.selection_start
                        s_end = smp.sample_buffer.selection_end
                      end

                      local src_id = #brain_sources + 1
                      brain_sources[src_id] = SourceRef.create(src_id, smp.name ~= "" and smp.name or "Untitled", pcm, rate, inst_idx, smp_idx, s_start, s_end)
                      count = count + 1
                    end
                  end
                end
              end
              brain_settings_signature = ""
              vb.views.brain_status.text = string.format("Brain: %d sources (+%d), %d blocks (STALE)", #brain_sources, count, #brain_blocks)
            end
          }
        },
        vb:row{
          spacing = 6,
          vb:button{
            text = "Generate / Rebuild Brain", width = 160,
            notifier = function()
              if JobRunner.is_running() then return end
              if #brain_sources == 0 then
                renoise.app():show_warning("No brain sources added.")
                return
              end
              
              JobRunner.start(
                function(job)
                  local temp_blocks = {}
                  local start_id = 1
                  for i = 1, #brain_sources do
                    local ref = brain_sources[i]
                    if ref.enabled then
                      ref:reload(brain_settings.channel_mode, brain_settings.use_selection)
                      local blocks, next_id = BlockGenerator.generate(ref, brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, start_id, job)
                      for _, b in ipairs(blocks) do
                        temp_blocks[#temp_blocks + 1] = b
                      end
                      start_id = next_id
                    end
                  end
                  return temp_blocks
                end,
                function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                function(temp_blocks)
                  brain_blocks = temp_blocks
                  synapses_built = false
                  brain_settings_signature = string.format("%d_%f_%d_%d_%d_%s", brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, brain_settings.channel_mode, #brain_sources, tostring(brain_settings.use_selection))
                  vb.views.brain_status.text = string.format("Brain: %d samples, %d total blocks", #brain_sources, #brain_blocks)
                  vb.views.job_status.text = ""
                  update_job_ui(false)
                end,
                function(err)
                  brain_settings_signature = ""
                  vb.views.job_status.text = "Brain analysis failed."
                  update_job_ui(false)
                  renoise.app():show_error("Brain analysis failed: " .. tostring(err))
                end
              )
              update_job_ui(true)
            end
          },
          vb:button{
            text = "Clear Brain", width = 90,
            notifier = function()
              if JobRunner.is_running() then return end
              brain_sources = {}
              brain_blocks = {}
              synapses_built = false
              brain_settings_signature = ""
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
                  synapses_signature = string.format("%f_%f_%d_%d", ratio, n_ratio, fft_start, fft_end)
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
        },
        vb:row{
          spacing = 6,
          vb:checkbox{ value = normalize_output, notifier = function(v) normalize_output = v end },
          vb:text{ text = "Output Normalize (0.98 ceiling)" },
          vb:space{ width = 20 },
          vb:text{ text = "Num Synapses:" },
          vb:valuebox{ min = 1, max = 1000, value = num_synapses, step = 1, notifier = function(v) num_synapses = v end }
        }
      }
    },

    -- Render Action & Persistence
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

          local current_target_signature = string.format("%d_%f_%d_%d_%s", target_settings.block_size, target_settings.overlap, target_settings.window_type, target_settings.channel_mode, tostring(target_settings.use_selection))
          if target_blocks_signature ~= current_target_signature then
            renoise.app():show_warning("Target settings have changed. Please re-analyze the target sample before rendering.")
            return
          end

          local current_brain_signature = string.format("%d_%f_%d_%d_%d_%s", brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, brain_settings.channel_mode, #brain_sources, tostring(brain_settings.use_selection))
          if brain_settings_signature ~= current_brain_signature then
            renoise.app():show_warning("Brain settings or sources have changed. Please click 'Generate / Rebuild Brain' before rendering.")
            return
          end

          JobRunner.start(
            function(job)
              if (algo == Constants.ALGO_SYNAPTIC or algo == Constants.ALGO_SYNAPTIC_SLIDE) then
                local current_synapse_signature = string.format("%f_%f_%d_%d", ratio, n_ratio, fft_start, fft_end)
                if not synapses_built or synapses_signature ~= current_synapse_signature then
                  SynapseBuilder.build_fixed(brain_blocks, num_synapses, ratio, n_ratio, fft_start, fft_end, job)
                  synapses_built = true
                  synapses_signature = current_synapse_signature
                end
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
                normalize = normalize_output,
                num_synapses = num_synapses,
                brain_gain = brain_gain,
                job = job
              }

              local out_pcm, err = Renderer.render(brain_blocks, target_blocks, options)
              if not out_pcm then error(err) end
              return out_pcm
            end,
            function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
            function(out_pcm)
              local out_rate = target_source and target_source.sample_rate or Constants.DEFAULT_SAMPLE_RATE
              SampleWriter.write_new_instrument(out_pcm, nil, out_rate, "SampleBrain")
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
      },
      vb:button{
        text = "Save Session...",
        width = 110, height = 30,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_write("sb_session", "Save SampleBrain Session")
          if path ~= "" then
            local state = {
              version = 1,
              brain_settings = brain_settings,
              target_settings = target_settings,
              params = {
                ratio = ratio, n_ratio = n_ratio,
                fft_start = fft_start, fft_end = fft_end,
                usage_importance = usage_importance,
                usage_falloff = usage_falloff,
                stickiness = stickiness,
                slide_error = slide_error,
                algo = algo, stretch = stretch,
                autotune = autotune, n_mix = n_mix,
                target_mix = target_mix,
                normalize_output = normalize_output
              }
            }
            local ok, err = Session.save(path, state)
            if ok then
              renoise.app():show_status("SampleBrain session saved successfully.")
            else
              renoise.app():show_error("Failed to save session: " .. tostring(err))
            end
          end
        end
      },
      vb:button{
        text = "Load Session...",
        width = 110, height = 30,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_read({ "*.sb_session", "*.txt" }, "Load SampleBrain Session")
          if path ~= "" then
            local state, err = Session.load(path)
            if state and state.params then
              ratio = state.params.ratio or ratio
              n_ratio = state.params.n_ratio or n_ratio
              fft_start = state.params.fft_start or fft_start
              fft_end = state.params.fft_end or fft_end
              usage_importance = state.params.usage_importance or usage_importance
              usage_falloff = state.params.usage_falloff or usage_falloff
              stickiness = state.params.stickiness or stickiness
              slide_error = state.params.slide_error or slide_error
              algo = state.params.algo or algo
              stretch = state.params.stretch or stretch
              autotune = state.params.autotune or autotune
              n_mix = state.params.n_mix or n_mix
              target_mix = state.params.target_mix or target_mix
              normalize_output = state.params.normalize_output or false
              
              if state.brain_settings then brain_settings = state.brain_settings end
              if state.target_settings then target_settings = state.target_settings end
              
              renoise.app():show_status("SampleBrain session loaded successfully.")
            else
              renoise.app():show_error("Failed to load session: " .. tostring(err))
            end
          end
        end
      }
    }
  }

  dialog = renoise.app():show_custom_dialog("SampleBrain for Renoise", content)
end

return MainDialog
