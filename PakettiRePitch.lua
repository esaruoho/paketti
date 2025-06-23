local dialog=nil

local function log2(x) return math.log(x)/math.log(2) end
local function midi2freq(x) return 440*(2^((x-69)/12)) end
local function freq2midi(x) return 69+(12*log2(x/440)) end

local function round(x)
  if x>=0 then return math.floor(x+0.5)
  else return math.ceil(x-0.5) end
end

local function get_note_letter(x)
  local note = round(x)
  -- MIDI note 60 is middle C (C4)
  -- Calculate octave based on this reference point
  local octave = math.floor((note - 12) / 12)
  local letters = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
  -- Get the note name from the letters table
  local note_name = letters[(note % 12) + 1]
  -- Format the octave number without the minus sign
  return note_name .. math.abs(octave)
end

local function analyze_sample(cycles)
  local s=renoise.song()
  local smp=s.selected_sample
  local buf=smp.sample_buffer
  if not buf.has_sample_data then return nil,"No sample data." end
  local sel_start=buf.selection_start
  local sel_end=buf.selection_end
  if sel_end<=sel_start then return nil,"Invalid selection." end
  local frames=1+(sel_end-sel_start)
  local rate=buf.sample_rate
  local freq=rate/(frames/cycles)
  local midi=freq2midi(freq)
  local nearest=round(midi)
  local cents=(nearest-midi)*100
  return {
    frames=frames,
    freq=freq,
    midi=midi,
    nearest=nearest,
    cents=cents,
    letter=get_note_letter(midi)
  }
end

local function set_pitch(data)
  local smp=renoise.song().selected_sample
  local diff=round(data.midi)-60
  -- Clamp transpose to valid range (-120 to 120)
  local transpose_value = -diff
  transpose_value = math.max(-120, math.min(120, transpose_value))
  smp.transpose = transpose_value
  -- data.cents directly tells us how many 1/128ths of a semitone we need
  local fine_tune_steps = round(data.cents)
  -- Clamp to valid range (-128 to 127)
  fine_tune_steps = math.max(-128, math.min(127, fine_tune_steps))
  smp.fine_tune = fine_tune_steps
end

function pakettiSimpleSampleTuningDialog()
  if dialog and dialog.visible then dialog:close() return end
  local vb=renoise.ViewBuilder()
  local analysis = nil
  local txt=vb:text{
    width=300,
    text="Note: \nFinetune: \nMIDI: "
  }
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog=renoise.app():show_custom_dialog(
    "Paketti Simple Sample Tuning Calculator",
    vb:column{
      margin=10,
      vb:row{
        vb:text{text="Cycles:"},
        vb:textfield{
          width=40,
          text="1",
          id="cycles"
        },
        vb:button{
          text="Calculate",
          notifier=function()
            local cycles=tonumber(vb.views.cycles.text)
            if not cycles or cycles<=0 then
              renoise.app():show_status("Enter valid number of cycles.")
              return
            end
            local res,err=analyze_sample(cycles)
            if not res then
              renoise.app():show_status(err)
              return
            end
            analysis=res
            txt.text = 
              "Note: "..res.letter.." ("..string.format("%.2f",res.freq).." Hz)"..
              "\nFinetune: "..string.format("%.2f",res.cents).." cents"..
              "\nMIDI: "..string.format("%.2f",res.midi)
          end
        }
      },
      vb:row{txt},
      vb:row{
        vb:button{
          text="Set Pitch",
          notifier=function()
            if not analysis then
              renoise.app():show_status("Please analyze the sample first.")
              return
            end
            if analysis.letter=="C4" or analysis.letter=="C5" then
              renoise.app():show_status("Already close to standard pitch.")
              return
            end
            set_pitch(analysis)
            renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
          end
        },
        vb:button{
          text="Close",
          notifier=function() dialog:close() end
        }
      }
    },
    keyhandler
  )
end



