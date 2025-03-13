#!/bin/bash
beep
beep

CONFIG_FILE="/Users/esaruoho/Library/Preferences/Renoise/V3.4.3/Config.xml"

killall Renoise


# This command uses sed to replace 'false' with 'true' for the specific XML tag
sed -i 's/<ShowScriptingDevelopmentTools>false<\/ShowScriptingDevelopmentTools>/<ShowScriptingDevelopmentTools>true<\/ShowScriptingDevelopmentTools>/g' "$CONFIG_FILE"

cd /Applications
open -a Renoise.app
