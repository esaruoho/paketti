**DigiChain**

DigiChain is a web app made to make the creation of sample chains as easy as possible for use on the Digitakt (and any other sampler that can slice up samples).

Split the slices out of Octatrack, OP-1/OP-1 Field/OP-Z, or DigiChains own exported files.

Export samples chains for the Octatrack, OP-1/OP-1 Field/OP-Z, Dirtywave M8 with slice information auto-created.

Supports batch converting of files to a chosen bit depth and sample rate (mono/stereo).
Choose the way stereo files get processed to mono, with Left, Right, Sum, and Difference (Side) with live preview of the choice from the sample list.
Join the selected files together into a sample chain, with the option to pad all samples to be the same length for evenly sized slices (perfect for the Digitakt's fixed slice grids).

Use the simple editing tools to trim-right, normalize, reverse, or pitch up/down the samples.
Batch operations for trim-right, normalize and reverse.

Merge the selected files (layered on top of each other) into one stereo file with the merge tool, put different samples on each channel, or center them.

Import Octatrack .ot files to slice to individual samples for export or further processing/joining.

Import OP-1, OP-Z, OP-1 Field aif drum kits and slice them to individual samples. Slice up the OP-1 Field stereo tape files from their tape.json file.

Import syx samples from the Elektron MachineDrum.

Chains created in DigiChain retain their contained samples slice markers for later splitting back out if needed.

Pitch up all exported files by 1, 2 or 3 octaves to reduce the file-sizes.

When playing back samples from within the list directly out to the Digitakt, or another sampler - make use of the pop-markers that add a short audio burst at the beginning and end of the sample. Makes sure threshold record starts at the right time without losing  that first transient, with a visible marker at the end to trim to for a perfect loop. Choose from 0db marker, which will prevent the Digitakt from being able to further normalize the audio, or peak, to set the volume of the marker to the loudest peak in the sample being played back.

While originally created as a tool to help make evenly spaced sample chains to use on the Elektron Digitakt’s slice grid machine introduced in the 1.5 firmware update, DigiChain has grown to incorporate other features, many of which were suggested by the good folks over on the Elektronauts forum.

Once the files are in the list, they are ready to be ordered into chains, choose the chain length on the slice grid in the top left buttons group (shift+click to keep the selections already in the list) – the list will show a green line to indicate when a chain ends and a new one begins below.

Each sample can also be sliced into new samples, or edited with a selection of basic destructive sample edits – if you want to keep the original around, duplicate a sample before making edits.

Shift+clicking on either of the join buttons will resample back into the list rather than out to a file.

By default, the app will open in the 48k/16bit mono context – great for the Digitakt! – but if you want to create chains for other samplers, switch up the context, the 44.1k/24bit stereo is perfect for the Octatrack, if you have a bunch of samples and want to just convert them to what the OT expects, set the context, drop them in the list, hit the download button – you will get out a zip file containing all the processed files with their folder structure intact ready to drop on the OT’s CF card.

If you want to move a sample around before exporting, change its folder path value in the sample edit panel.

While it is a web app, once loaded, there is no connection required, and can be installed as an app on most OSs.

There is a full complement of keyboard shortcuts to help navigate through things quickly.

see the keyboard-shortcuts.md for details.
