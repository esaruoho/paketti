# Envelope corruption on Paketti reload

Confirmed using the original PakettiStretch.lua startup tail, actual Renoise ViewBuilder checkbox behavior, and a mock song/device (no user instrument modified).

Reload created a checkbox with value false and then check_and_set_envelope_status set it true when the existing Volume AHDSR was enabled. That programmatic assignment invoked the notifier. It rewrote Decay to zero, Sustain to one, Release to 0.024, Release Scaling to one, operator to three, NNA to two, and changed sample looping from off to forward. Enabled remained true in this reproduced reload case. The explicit false branch separately disabled the envelope, changed operator to one and NNA to one, and turned forward looping off; that branch is not demonstrated as the enabled-envelope reload outcome.

Live parameter names confirmed parameter eight is Release Scaling, not volume gain. The hardcoded 480/20000 Release conversion was not an actual millisecond conversion: the live device formatted value 0.024 as 0.8 ms. Increasing Sustain and enabling looping can remove the intended amplitude contour and prolong loud playback; audible noise was reported by the user, not reproduced by playing audio.

Final fix removes the duplicate startup checkbox, all activation/deactivation writes from Timestretch, and automatic enabling from Release editing. Existing envelopes remain enabled or disabled as they were. Explicit Release and Release Scaling sliders own only their respective parameters. The first-match-across-all-sets lookup is replaced by the selected sample's assigned modulation set.

Original envelope values were not backed up by the destructive code; this fix prevents recurrence but cannot reconstruct them.
