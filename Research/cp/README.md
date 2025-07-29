# command_palette

Navigate and configure a song using the keyboard.

Provides two key-bindings in *Global / Tools*

- `Open command palette`
- `Repeat last command`

Additionally, there are a few shortcuts to open the most commonly used palettes without going through the main palette first (search for `palette` in the keybindings menu to find them or see below).

### usage

- open the command palette
- search for what you want by typing letters
- change the selected command with up or down
- type some number
- press enter to apply and exit
- delete your input with backspace
- escape will cancel the command and close the popup
- press left to recall previous commands

### command types

- `number` commands are the most common, they will show a `#` symbol in your top bar when you select them. These accept a single number that you can type in as soon as you have the command selected and it will be executed immeditately when the input is changed. For example type `i` to select the `select instrument` command then type 2 to select instrument `02`.

- `action` commands either require no input or more complex input that can be set in a separate window. These won't do anything until you press enter. They have the sign `>`. For example the `load plugin` command will open a secondary palette that will let you select a plugin, or the `par` (select parameters on DSP device) will let you select and move slider on DSP devices.

- `string` commands can for example rename things. These are noted with the `=` sign and they will open a separate text input window for you to provide the text string. Try the `nt` command to name a pattern.


Some commands open secondary palettes, these work the same way: just type or navigate until you have the match then hit `enter`. Some number commands will let you execute them without input and they will open a search palette for you to pick something by text instead of providing an index.

For example if you run the `t` (select track) command without an input number it will list all the tracks by name and will let you search and navigate it similarly to the main palette. The same thing works for instruments, samples or sections and even DSP devices across the whole song. If you name your things right this can help you a lot in navigating using the keyboard.

### shortcuts

On top of the main key-bindings, the most common secondary palettes are exposed as shortcuts found in *Global / Tools*
- Open DSP palette
- Open instrument palette
- Open pattern palette
- Open phrase palette
- Open plugin palette
- Open sequence palette
- Open track palette
