-- SampleBrain/ui/MainDialog.lua
-- Native Renoise ViewBuilder Dialog for SampleBrain (Authentic 3-Column SampleBrain 0.18 Layout)

local SampleReader = require("SampleBrain.renoise.SampleReader")
local SampleWriter = require("SampleBrain.renoise.SampleWriter")
local BlockGenerator = require("SampleBrain.analysis.BlockGenerator")
local SynapseBuilder = require("SampleBrain.analysis.SynapseBuilder")
local Renderer = require("SampleBrain.render.Renderer")
local SourceRef = require("SampleBrain.model.SourceRef")
local JobRunner = require("SampleBrain.jobs.JobRunner")
local Session = require("SampleBrain.persistence.Session")
local Constants = require("SampleBrain.Constants")

local Logger = require("SampleBrain.Logger")
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
local n_ratio = 0.0 -- 0.00 = raw only (matches C++ default 0.00)
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
local independent_stereo = false

local function update_job_ui(is_running)
  if vb and vb.views.btn_cancel then
    vb.views.btn_cancel.visible = is_running
  end
end

local function refresh_source_list(active_src_idx, active_msg)
  if not vb or not vb.views.brain_source_list then return end
  if #brain_sources == 0 then
    vb.views.brain_source_list.text = "No sources added."
    if vb.views.source_selector_popup then
      vb.views.source_selector_popup.items = { "None" }
      vb.views.source_selector_popup.value = 1
    end
    return
  end
  local lines = {}
  local popup_items = {}
  for i, ref in ipairs(brain_sources) do
    local state = ref.enabled and "[x]" or "[ ]"
    local frames_str = string.format("%.1fk", (ref.captured_range_end - ref.captured_range_start + 1) / 1000)
    
    local source_status = ""
    if active_src_idx then
      if i < active_src_idx then
        source_status = "[DONE]"
      elseif i == active_src_idx then
        source_status = string.format(">>> [ANALYZING: %s] <<<", active_msg or "Processing...")
      else
        source_status = "[WAIT]"
      end
    else
      source_status = ref.enabled and string.format("(%s frames)", frames_str) or "(OFF)"
    end

    lines[#lines + 1] = string.format("%02d: %s %s %s", i, state, ref.name, source_status)
    popup_items[#popup_items + 1] = string.format("%d: %s %s", i, ref.name, ref.enabled and "[ON]" or "[OFF]")
  end
  vb.views.brain_source_list.text = table.concat(lines, "\n")
  if vb.views.source_selector_popup then
    vb.views.source_selector_popup.items = popup_items
    if vb.views.source_selector_popup.value > #popup_items then
      vb.views.source_selector_popup.value = math.max(1, #popup_items)
    end
  end
end

local function make_synapse_signature()
  return string.format("%f_%f_%d_%d_%s", ratio, n_ratio, fft_start, fft_end, tostring(independent_stereo))
end

local function build_required_graphs(job)
  local count = SynapseBuilder.build_fixed(brain_blocks, 1000, ratio, n_ratio, fft_start, fft_end, job, "mono")
  if independent_stereo then
    SynapseBuilder.build_fixed(brain_blocks, 1000, ratio, n_ratio, fft_start, fft_end, job, "left")
    SynapseBuilder.build_fixed(brain_blocks, 1000, ratio, n_ratio, fft_start, fft_end, job, "right")
  end
  return count
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
  refresh_source_list()
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

local function run_batch_render(count)
  if JobRunner.is_running() then return end
  if #target_blocks == 0 or #brain_blocks == 0 then
    renoise.app():show_warning("Need both Target and Brain samples. Please set Target and Rebuild Brain first.")
    return
  end

  local current_target_signature = string.format("%d_%f_%d_%d_%s", target_settings.block_size, target_settings.overlap, target_settings.window_type, target_settings.channel_mode, tostring(target_settings.use_selection))
  if target_blocks_signature ~= current_target_signature then
    renoise.app():show_warning("Target settings have changed. Please re-analyze the target sample before rendering.")
    return
  end

  local current_brain_signature = string.format("%d_%f_%d_%d_%d_%s", brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, brain_settings.channel_mode, #brain_sources, tostring(brain_settings.use_selection))
  if brain_settings_signature ~= current_brain_signature then
    renoise.app():show_warning("Brain settings or sources have changed. Please click '(re)generate brain' before rendering.")
    return
  end

  JobRunner.start(
    function(job)
      if (algo == Constants.ALGO_SYNAPTIC or algo == Constants.ALGO_SYNAPTIC_SLIDE) then
        local current_synapse_signature = make_synapse_signature()
        if not synapses_built or synapses_signature ~= current_synapse_signature then
          build_required_graphs(job)
          synapses_built = true
          synapses_signature = current_synapse_signature
        end
      end

      local results = {}
      local algos = { Constants.ALGO_BASIC, Constants.ALGO_REVERSED, Constants.ALGO_SYNAPTIC, Constants.ALGO_SYNAPTIC_SLIDE }
      local algo_names = { "Basic", "Reversed", "Synaptic", "Synaptic Slide" }

      for i = 1, count do
        if job.cancelled then break end

        -- Systematic parameter variation per pass
        local pass_algo = algos[((i - 1) % #algos) + 1]
        local pass_ratio = math.max(0.0, math.min(1.0, ratio + ((i - 1) - count / 2) * 0.06))
        local pass_stickiness = math.max(0.0, math.min(1.0, stickiness + ((i % 5) * 0.12)))
        local pass_autotune = math.max(0.0, math.min(1.0, autotune + ((i % 4) * 0.10)))
        local pass_stretch = math.max(1, math.min(50, stretch + (i % 3)))
        local pass_slide_error = math.max(10, math.min(10000, slide_error + (i * 120)))

        local options = {
          block_size = target_settings.block_size,
          overlap = target_settings.overlap,
          window_type = target_settings.window_type,
          algo = pass_algo,
          ratio = pass_ratio,
          n_ratio = n_ratio,
          fft_start = fft_start,
          fft_end = fft_end,
          usage_importance = usage_importance,
          usage_falloff = usage_falloff,
          stickiness = pass_stickiness,
          slide_error = pass_slide_error,
          stretch = pass_stretch,
          autotune = pass_autotune,
          n_mix = n_mix,
          target_mix = target_mix,
          normalize = normalize_output,
          num_synapses = num_synapses,
          brain_gain = brain_gain,
          independent_stereo = independent_stereo,
          job = job
        }

        local out_l, out_r = Renderer.render(brain_blocks, target_blocks, options)
        if not out_l then error(out_r or "Render failed") end

        results[#results + 1] = {
          left = out_l,
          right = out_r,
          name = string.format("Paketti SB [%02d/%02d] %s (ratio=%.2f, tune=%.2f)", i, count, algo_names[pass_algo], pass_ratio, pass_autotune)
        }
      end

      return results
    end,
    function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
    function(results)
      local out_rate = target_source and target_source.sample_rate or Constants.DEFAULT_SAMPLE_RATE
      local song = renoise.song()
      local start_insert_idx = song.selected_instrument_index

      for i, res in ipairs(results) do
        local target_slot = math.min(#song.instruments + 1, start_insert_idx + i)
        SampleWriter.write_new_instrument(res.left, res.right, out_rate, res.name, target_slot)
      end

      vb.views.job_status.text = string.format("Batch created %d instruments!", #results)
      update_job_ui(false)
      renoise.app():show_status(string.format("Paketti SampleBrain: Successfully created %d instruments starting at slot +1!", #results))
    end,
    function(err)
      vb.views.job_status.text = "Batch render failed."
      update_job_ui(false)
      renoise.app():show_error("Batch render failed: " .. tostring(err))
    end
  )
  update_job_ui(true)
end

function MainDialog.show()
  Logger.write("Dialog opened; diagnostics=" .. Logger.path())
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()

  local content = vb:column{
    width = 840,
    margin = 8,
    spacing = 6,

    -- 3-Column Main Layout
    vb:row{
      spacing = 8,

      -- Left Column: Brain Tweaks
      vb:column{
        width = 280, style = "panel", margin = 6, spacing = 4,
        vb:row{ vb:text{ text = "brain tweaks", font = "bold" } },
        
        vb:row{
          spacing = 2,
          vb:text{ text = "fft / mfcc", width = 100 },
          vb:minislider{ id = "slide_ratio", min = 0.0, max = 1.0, value = ratio, width = 90, notifier = function(v) ratio = v; vb.views.box_ratio.value = v end },
          vb:valuebox{ id = "box_ratio", min = 0.0, max = 1.0, value = ratio, steps = { 0.01, 0.1 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) ratio = v; vb.views.slide_ratio.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "raw / norm", width = 100 },
          vb:minislider{ id = "slide_n_ratio", min = 0.0, max = 1.0, value = n_ratio, width = 90, notifier = function(v) n_ratio = v; vb.views.box_n_ratio.value = v end },
          vb:valuebox{ id = "box_n_ratio", min = 0.0, max = 1.0, value = n_ratio, steps = { 0.01, 0.1 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) n_ratio = v; vb.views.slide_n_ratio.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "fft subsection", width = 100 },
          vb:text{ text = "S:", width = 13 },
          vb:valuebox{ id = "box_fft_start", min = 1, max = 100, value = fft_start, steps = { 1, 5 }, width = 45, notifier = function(v) fft_start = v end },
          vb:space{ width = 12 },
          vb:text{ text = "E:", width = 13 },
          vb:valuebox{ id = "box_fft_end", min = 1, max = 100, value = fft_end, steps = { 1, 5 }, width = 68, notifier = function(v) fft_end = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "novelty", width = 100 },
          vb:minislider{ id = "slide_novelty", min = 0.0, max = 1.0, value = usage_importance, width = 90, notifier = function(v) usage_importance = v; vb.views.box_novelty.value = v end },
          vb:valuebox{ id = "box_novelty", min = 0.0, max = 1.0, value = usage_importance, steps = { 0.01, 0.05 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) usage_importance = v; vb.views.slide_novelty.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "boredom", width = 100 },
          vb:minislider{ id = "slide_boredom", min = 0.0, max = 1.0, value = usage_falloff, width = 90, notifier = function(v) usage_falloff = v; vb.views.box_boredom.value = v end },
          vb:valuebox{ id = "box_boredom", min = 0.0, max = 1.0, value = usage_falloff, steps = { 0.01, 0.05 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) usage_falloff = v; vb.views.slide_boredom.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "stickyness", width = 100 },
          vb:minislider{ id = "slide_stickiness", min = 0.0, max = 1.0, value = stickiness, width = 90, notifier = function(v) stickiness = v; vb.views.box_stickiness.value = v end },
          vb:valuebox{ id = "box_stickiness", min = 0.0, max = 1.0, value = stickiness, steps = { 0.01, 0.05 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) stickiness = v; vb.views.slide_stickiness.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "search stretch", width = 100 },
          vb:minislider{ id = "slide_stretch", min = 1, max = 50, value = stretch, width = 90, notifier = function(v) stretch = v; vb.views.box_stretch.value = v end },
          vb:valuebox{ id = "box_stretch", min = 1, max = 50, value = stretch, steps = { 1, 5 }, width = 68, notifier = function(v) stretch = v; vb.views.slide_stretch.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "algorithm", width = 100 },
          vb:popup{ items = { "Basic", "Reversed", "Synaptic", "Synaptic Slide" }, value = algo, width = 162, notifier = function(v) algo = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "num synapses", width = 100 },
          vb:minislider{ id = "slide_synapses", min = 1, max = 1000, value = num_synapses, width = 90, notifier = function(v) num_synapses = v; vb.views.box_synapses.value = v end },
          vb:valuebox{ id = "box_synapses", min = 1, max = 1000, value = num_synapses, steps = { 1, 10 }, width = 68, notifier = function(v) num_synapses = v; vb.views.slide_synapses.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "slide error", width = 100 },
          vb:minislider{ id = "slide_error", min = 0, max = 10000, value = slide_error, width = 90, notifier = function(v) slide_error = v; vb.views.box_error.value = v end },
          vb:valuebox{ id = "box_error", min = 0, max = 10000, value = slide_error, steps = { 10, 100 }, width = 68, tostring = function(v) return string.format("%d", math.floor(v)) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) slide_error = v; vb.views.slide_error.value = v end }
        }
      },

      -- Center Column: Target Sound & Mix
      vb:column{
        width = 260, style = "panel", margin = 6, spacing = 4,
        vb:row{ vb:text{ text = "target sound", font = "bold" } },
        
        vb:row{
          vb:button{
            text = "load target", width = 245,
            notifier = function()
              if JobRunner.is_running() then return end
              local smp = renoise.song().selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                JobRunner.start(
                  function(job)
                    local pcm, rate = SampleReader.read_channel(smp, target_settings.channel_mode, target_settings.use_selection)
                    if not pcm then error("Failed to read sample") end
                    
                    local song = renoise.song()
                    local inst_idx = song.selected_instrument_index
                    local smp_idx = song.selected_sample_index
                    local s_start, s_end = 1, smp.sample_buffer.number_of_frames
                    if target_settings.use_selection and smp.sample_buffer.selection_start > 0 and smp.sample_buffer.selection_end > 0 then
                      s_start = smp.sample_buffer.selection_start
                      s_end = smp.sample_buffer.selection_end
                    end

                    local pcm_l, pcm_r = SampleReader.read_stereo_exact(smp, s_start, s_end)
                    local temp_target_source = SourceRef.create(9999, smp.name, pcm, rate, inst_idx, smp_idx, s_start, s_end, pcm_l, pcm_r, smp.sample_buffer.number_of_channels)
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
          }
        },
        vb:row{ vb:text{ id = "target_status", text = "Target: None selected", style = "disabled" } },
        vb:row{
          spacing = 4,
          vb:text{ text = "block size", width = 100 },
          vb:popup{ items = { "256", "500", "512", "768", "1000", "1024", "1500", "2048", "3000", "4096" }, value = 6, width = 140, notifier = function(v) target_settings.block_size = ({256,500,512,768,1000,1024,1500,2048,3000,4096})[v] end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "block overlap", width = 100 },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, width = 140, notifier = function(v) target_settings.overlap = ({0.25,0.5,0.75})[v] end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "window shape", width = 100 },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, width = 140, notifier = function(v) target_settings.window_type = v end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "channel mode", width = 100 },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, width = 140, notifier = function(v) target_settings.channel_mode = v end }
        },
        vb:row{
          spacing = 4,
          vb:checkbox{ value = target_settings.use_selection, notifier = function(v) target_settings.use_selection = v end },
          vb:text{ text = "use selection only" }
        },

        vb:space{ height = 10 },
        vb:row{ vb:text{ text = "mix", font = "bold" } },

        vb:row{
          spacing = 2,
          vb:text{ text = "autotune", width = 85 },
          vb:minislider{ id = "slide_autotune", min = 0.0, max = 1.0, value = autotune, width = 88, notifier = function(v) autotune = v; vb.views.box_autotune.value = v end },
          vb:valuebox{ id = "box_autotune", min = 0.0, max = 1.0, value = autotune, steps = { 0.01, 0.1 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) autotune = v; vb.views.slide_autotune.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "normalised", width = 85 },
          vb:minislider{ id = "slide_nmix", min = 0.0, max = 1.0, value = n_mix, width = 88, notifier = function(v) n_mix = v; vb.views.box_nmix.value = v end },
          vb:valuebox{ id = "box_nmix", min = 0.0, max = 1.0, value = n_mix, steps = { 0.01, 0.1 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) n_mix = v; vb.views.slide_nmix.value = v end }
        },
        vb:row{
          spacing = 2,
          vb:text{ text = "brain / target", width = 85 },
          vb:minislider{ id = "slide_tmix", min = 0.0, max = 1.0, value = target_mix, width = 88, notifier = function(v) target_mix = v; vb.views.box_tmix.value = v end },
          vb:valuebox{ id = "box_tmix", min = 0.0, max = 1.0, value = target_mix, steps = { 0.01, 0.1 }, width = 68, tostring = function(v) return string.format("%.2f", v) end, tonumber = function(s) return tonumber(s) end, notifier = function(v) target_mix = v; vb.views.slide_tmix.value = v end }
        },
        vb:row{
          spacing = 4,
          vb:checkbox{ value = independent_stereo, notifier = function(v) independent_stereo = v end },
          vb:text{ text = "independent stereo search" }
        },
        vb:row{
          spacing = 4,
          vb:checkbox{ value = normalize_output, notifier = function(v) normalize_output = v end },
          vb:text{ text = "output normalize (0.98)" }
        }
      },

      -- Right Column: Brain Contents & Brain Settings
      vb:column{
        width = 370, style = "panel", margin = 6, spacing = 4,
        vb:row{
          vb:text{ text = "brain contents", font = "bold" },
          vb:space{ width = 180 },
          vb:button{
            text = "all", width = 38,
            notifier = function()
              for _, ref in ipairs(brain_sources) do ref.enabled = true end
              refresh_source_list()
            end
          },
          vb:button{
            text = "none", width = 38,
            notifier = function()
              for _, ref in ipairs(brain_sources) do ref.enabled = false end
              refresh_source_list()
            end
          }
        },

        vb:row{
          vb:multiline_text{
            id = "brain_source_list",
            text = "No sources added.",
            width = 354,
            height = 100,
            font = "mono"
          }
        },

        vb:row{
          spacing = 4,
          vb:text{ text = "source:", width = 50 },
          vb:popup{
            id = "source_selector_popup",
            items = { "None" },
            value = 1,
            width = 180
          },
          vb:button{
            text = "toggle", width = 58,
            notifier = function()
              local sel_idx = vb.views.source_selector_popup.value
              if brain_sources[sel_idx] then
                brain_sources[sel_idx].enabled = not brain_sources[sel_idx].enabled
                refresh_source_list()
              end
            end
          },
          vb:button{
            text = "remove", width = 58,
            notifier = function()
              local sel_idx = vb.views.source_selector_popup.value
              if brain_sources[sel_idx] then
                table.remove(brain_sources, sel_idx)
                brain_settings_signature = ""
                synapses_built = false
                vb.views.brain_status.text = string.format("Brain: %d sources, %d blocks (STALE)", #brain_sources, #brain_blocks)
                refresh_source_list()
              end
            end
          }
        },

        vb:row{
          spacing = 4,
          vb:button{
            text = "add sample", width = 114,
            notifier = function()
              local song = renoise.song()
              local inst = song.selected_instrument
              local smp = song.selected_sample
              if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
                local inst_idx = song.selected_instrument_index
                local smp_idx = song.selected_sample_index
                local pcm, rate = SampleReader.read_channel(smp, brain_settings.channel_mode, brain_settings.use_selection)
                if not pcm then renoise.app():show_warning("Failed to read sample") return end
                
                local s_start, s_end = 1, smp.sample_buffer.number_of_frames
                if brain_settings.use_selection and smp.sample_buffer.selection_start > 0 and smp.sample_buffer.selection_end > 0 then
                  s_start = smp.sample_buffer.selection_start
                  s_end = smp.sample_buffer.selection_end
                end

                local src_id = #brain_sources + 1
                local pcm_l, pcm_r = SampleReader.read_stereo_exact(smp, s_start, s_end)
                local ref = SourceRef.create(src_id, smp.name, pcm, rate, inst_idx, smp_idx, s_start, s_end, pcm_l, pcm_r, smp.sample_buffer.number_of_channels)
                brain_sources[src_id] = ref
                
                brain_settings_signature = ""
                vb.views.brain_status.text = string.format("Brain: %d sources, %d blocks (STALE)", #brain_sources, #brain_blocks)
                refresh_source_list()
              else
                renoise.app():show_warning("Selected sample has no audio data.")
              end
            end
          },
          vb:button{
            text = "add inst", width = 82,
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
                    local pcm_l, pcm_r = SampleReader.read_stereo_exact(smp, s_start, s_end)
                    brain_sources[src_id] = SourceRef.create(src_id, smp.name, pcm, rate, inst_idx, smp_idx, s_start, s_end, pcm_l, pcm_r, smp.sample_buffer.number_of_channels)
                    count = count + 1
                  end
                end
              end
              brain_settings_signature = ""
              vb.views.brain_status.text = string.format("Brain: %d sources (+%d), %d blocks (STALE)", #brain_sources, count, #brain_blocks)
              refresh_source_list()
            end
          },
          vb:button{
            text = "add all", width = 82,
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
                      local pcm_l, pcm_r = SampleReader.read_stereo_exact(smp, s_start, s_end)
                      brain_sources[src_id] = SourceRef.create(src_id, smp.name ~= "" and smp.name or "Untitled", pcm, rate, inst_idx, smp_idx, s_start, s_end, pcm_l, pcm_r, smp.sample_buffer.number_of_channels)
                      count = count + 1
                    end
                  end
                end
              end
              brain_settings_signature = ""
              vb.views.brain_status.text = string.format("Brain: %d sources (+%d), %d blocks (STALE)", #brain_sources, count, #brain_blocks)
              refresh_source_list()
            end
          }
        },

        vb:row{
          spacing = 4,
          vb:text{ text = "block size", width = 100 },
          vb:popup{ items = { "256", "500", "512", "768", "1000", "1024", "1500", "2048", "3000", "4096" }, value = 6, width = 148, notifier = function(v) brain_settings.block_size = ({256,500,512,768,1000,1024,1500,2048,3000,4096})[v] end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "block overlap", width = 100 },
          vb:popup{ items = { "25%", "50%", "75%" }, value = 2, width = 148, notifier = function(v) brain_settings.overlap = ({0.25,0.5,0.75})[v] end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "window shape", width = 100 },
          vb:popup{ items = { "Rectangle", "Hann", "Hamming", "Blackman", "Bartlett", "Gaussian", "Flat Top", "Dodgy" }, value = 2, width = 148, notifier = function(v) brain_settings.window_type = v end }
        },
        vb:row{
          spacing = 4,
          vb:text{ text = "channel mode", width = 100 },
          vb:popup{ items = { "Mix", "Left", "Right" }, value = 1, width = 148, notifier = function(v) brain_settings.channel_mode = v end }
        },
        vb:row{
          spacing = 4,
          vb:checkbox{ value = brain_settings.use_selection, notifier = function(v) brain_settings.use_selection = v end },
          vb:text{ text = "use selection only" }
        },

        vb:row{
          vb:button{
            text = "(re)generate brain", width = 354,
            notifier = function()
              if JobRunner.is_running() then return end
              if #brain_sources == 0 then
                renoise.app():show_warning("No brain sources added. Please add samples first.")
                return
              end
              
              JobRunner.start(
                function(job)
                  local temp_blocks = {}
                  local start_id = 1
                  for i = 1, #brain_sources do
                    local ref = brain_sources[i]
                    if ref.enabled then
                      local ok, reload_err = ref:reload(brain_settings.channel_mode, brain_settings.use_selection)
                      if not ok then
                        error(string.format("Brain source %d '%s' could not be reloaded: %s", i, ref.name, reload_err or "Sample missing"))
                      end
                      
                      job.status = string.format("Brain [%d/%d] %s: Starting...", i, #brain_sources, ref.name)
                      local blocks, next_id = BlockGenerator.generate(ref, brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, start_id, job)
                      for _, b in ipairs(blocks) do
                        temp_blocks[#temp_blocks + 1] = b
                      end
                      start_id = next_id
                    end
                  end

                  -- Auto-grow synapses so brain is fully prepared for matching
                  build_required_graphs(job)

                  return temp_blocks
                end,
                function(pct, msg)
                  vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100)
                  if job.status then
                    local src_idx, src_msg = job.status:match("Brain %[(%d+)/%d+%] .+: (.+)")
                    if src_idx then
                      refresh_source_list(tonumber(src_idx), src_msg)
                    end
                  end
                end,
                function(temp_blocks)
                  brain_blocks = temp_blocks
                  synapses_built = true
                  synapses_signature = make_synapse_signature()
                  brain_settings_signature = string.format("%d_%f_%d_%d_%d_%s", brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, brain_settings.channel_mode, #brain_sources, tostring(brain_settings.use_selection))
                  vb.views.brain_status.text = string.format("Brain: %d sources, %d blocks (Ready)", #brain_sources, #brain_blocks)
                  vb.views.job_status.text = ""
                  refresh_source_list()
                  update_job_ui(false)
                  renoise.app():show_status(string.format("SampleBrain: Brain built successfully (%d sources, %d blocks)!", #brain_sources, #brain_blocks))
                end,
                function(err)
                  brain_settings_signature = ""
                  vb.views.job_status.text = "Brain analysis failed."
                  refresh_source_list()
                  update_job_ui(false)
                  renoise.app():show_error("Brain analysis failed: " .. tostring(err))
                end
              )
              update_job_ui(true)
            end
          }
        },

        vb:row{
          spacing = 6,
          vb:button{
            text = "grow synapses", width = 124,
            notifier = function()
              if JobRunner.is_running() then return end
              if #brain_sources == 0 then
                renoise.app():show_warning("No brain sources added. Please add brain sources and click '(re)generate brain' first.")
                return
              end
              if #brain_blocks == 0 then
                renoise.app():show_warning("Brain has not been built yet. Please click '(re)generate brain' before growing synapses.")
                return
              end
              
              JobRunner.start(
                function(job)
                  return build_required_graphs(job)
                end,
                function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
                function(count)
                  synapses_built = true
                  synapses_signature = make_synapse_signature()
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
          },
          vb:button{
            text = "clear brain", width = 124,
            notifier = function()
              if JobRunner.is_running() then return end
              brain_sources = {}
              brain_blocks = {}
              synapses_built = false
              brain_settings_signature = ""
              vb.views.brain_status.text = "Brain: Empty"
              refresh_source_list()
            end
          }
        },
        vb:row{ vb:text{ id = "brain_status", text = "Brain: Empty", style = "disabled" } }
      }
    },

    -- Bottom Action Bar & Session Controls
    vb:row{
      spacing = 6,
      vb:button{
        text = "Render Output",
        width = 130, height = 28,
        notifier = function()
          if JobRunner.is_running() then return end
          if #target_blocks == 0 or #brain_blocks == 0 then
            renoise.app():show_warning("Need both Target and Brain samples. Please set Target and Rebuild Brain first.")
            return
          end

          local current_target_signature = string.format("%d_%f_%d_%d_%s", target_settings.block_size, target_settings.overlap, target_settings.window_type, target_settings.channel_mode, tostring(target_settings.use_selection))
          if target_blocks_signature ~= current_target_signature then
            renoise.app():show_warning("Target settings have changed. Please re-analyze the target sample before rendering.")
            return
          end

          local current_brain_signature = string.format("%d_%f_%d_%d_%d_%s", brain_settings.block_size, brain_settings.overlap, brain_settings.window_type, brain_settings.channel_mode, #brain_sources, tostring(brain_settings.use_selection))
          if brain_settings_signature ~= current_brain_signature then
            renoise.app():show_warning("Brain settings or sources have changed. Please click '(re)generate brain' before rendering.")
            return
          end

          JobRunner.start(
            function(job)
              if (algo == Constants.ALGO_SYNAPTIC or algo == Constants.ALGO_SYNAPTIC_SLIDE) then
                local current_synapse_signature = make_synapse_signature()
                if not synapses_built or synapses_signature ~= current_synapse_signature then
                  build_required_graphs(job)
                  synapses_built = true
                  synapses_signature = current_synapse_signature
                end
              end

              local options = {
                block_size = target_settings.block_size,
                overlap = target_settings.overlap,
                window_type = target_settings.window_type,
                algo = algo,
                ratio = ratio,
                n_ratio = n_ratio,
                fft_start = fft_start,
                fft_end = fft_end,
                usage_importance = usage_importance,
                usage_falloff = usage_falloff,
                stickiness = stickiness,
                slide_error = slide_error,
                stretch = stretch,
                autotune = autotune,
                n_mix = n_mix,
                target_mix = target_mix,
                normalize = normalize_output,
                num_synapses = num_synapses,
                brain_gain = brain_gain,
                independent_stereo = independent_stereo,
                job = job
              }

              local out_l, out_r = Renderer.render(brain_blocks, target_blocks, options)
              if not out_l then error(out_r or "Render failed") end
              return { left = out_l, right = out_r }
            end,
            function(pct, msg) vb.views.job_status.text = string.format("%s (%.1f%%)", msg, pct * 100) end,
            function(res)
              local out_rate = target_source and target_source.sample_rate or Constants.DEFAULT_SAMPLE_RATE
              SampleWriter.write_new_instrument(res.left, res.right, out_rate, "Paketti SampleBrain")
              vb.views.job_status.text = string.format("Rendered %d frames.", #res.left)
              update_job_ui(false)
              renoise.app():show_status("SampleBrain render complete!")
              if synapses_built then
                 vb.views.brain_status.text = string.format("Brain: %d blocks (Auto-synapses grown)", #brain_blocks)
              end
            end,
            function(err)
              vb.views.job_status.text = "Render failed."
              update_job_ui(false)
              renoise.app():show_error("Render failed: " .. tostring(err))
            end
          )
          update_job_ui(true)
        end
      },
      vb:button{
        text = "Make 10",
        width = 75, height = 28,
        notifier = function()
          run_batch_render(10)
        end
      },
      vb:button{
        text = "Make 20",
        width = 75, height = 28,
        notifier = function()
          run_batch_render(20)
        end
      },
      vb:button{
        text = "Save Session...",
        width = 140, height = 28,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_write("sb_session", "Save SampleBrain Session")
          if path and path ~= "" then
            local state = {
              version = 1,
              brain_settings = brain_settings,
              target_settings = target_settings,
              params = {
                ratio = ratio, n_ratio = n_ratio, fft_start = fft_start, fft_end = fft_end,
                usage_importance = usage_importance, usage_falloff = usage_falloff,
                stickiness = stickiness, algo = algo, stretch = stretch,
                slide_error = slide_error, num_synapses = num_synapses,
                autotune = autotune, n_mix = n_mix, target_mix = target_mix,
                normalize = normalize_output, independent_stereo = independent_stereo
              }
            }
            local ok, err = Session.save(path, state)
            if ok then
              renoise.app():show_status("Session saved successfully.")
            else
              renoise.app():show_error("Failed to save session: " .. tostring(err))
            end
          end
        end
      },
      vb:button{
        text = "Load Session...",
        width = 140, height = 28,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_read({ "sb_session", "txt" }, "Load SampleBrain Session")
          if path and path ~= "" then
            local state, err = Session.load(path)
            if state and state.params then
              ratio = state.params.ratio or ratio
              n_ratio = state.params.n_ratio or n_ratio
              fft_start = state.params.fft_start or fft_start
              fft_end = state.params.fft_end or fft_end
              usage_importance = state.params.usage_importance or usage_importance
              usage_falloff = state.params.usage_falloff or usage_falloff
              stickiness = state.params.stickiness or stickiness
              algo = state.params.algo or algo
              stretch = state.params.stretch or stretch
              slide_error = state.params.slide_error or slide_error
              num_synapses = state.params.num_synapses or num_synapses
              autotune = state.params.autotune or autotune
              n_mix = state.params.n_mix or n_mix
              target_mix = state.params.target_mix or target_mix
              normalize_output = state.params.normalize or normalize_output
              independent_stereo = state.params.independent_stereo or independent_stereo
              
              if state.brain_settings then brain_settings = state.brain_settings end
              if state.target_settings then target_settings = state.target_settings end

              renoise.app():show_status("Session loaded successfully.")
            else
              renoise.app():show_error("Failed to load session: " .. tostring(err))
            end
          end
        end
      },
      vb:button{
        id = "btn_cancel",
        text = "Cancel Job",
        width = 110, height = 28,
        visible = false,
        notifier = function()
          if JobRunner.is_running() then
            JobRunner.cancel()
            vb.views.job_status.text = "Job cancelled."
            update_job_ui(false)
          end
        end
      },
      vb:text{ id = "job_status", text = "", width = 230, style = "disabled" }
    }
  }

  dialog = renoise.app():show_custom_dialog("SampleBrain for Renoise", content)
end

return MainDialog
