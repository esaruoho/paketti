-- PakettiVersionGuard.lua
--
-- Warns the user when the Renoise 3.1 build of Paketti (Paketti31, API 5) has
-- been installed into a newer Renoise. That combination half-works: menus and
-- dialogs appear, but anything relying on API 6+ silently misbehaves, so it
-- reads as "Paketti is full of bugs" rather than "wrong build installed".
-- A user on Reddit reported exactly this - the Slices dialog misbehaving -
-- and it turned out to be Paketti 3.1 running on Renoise 3.5.
--
-- HOW THE BUILD IDENTIFIES ITSELF
-- There are two independent signals, because a single one can fail quietly:
--
--   1. PAKETTI_BUILD_FLAVOR below. The GitHub Actions job `package-api5`
--      rewrites this one line from "3.54" to "3.1" while it assembles the
--      legacy .xrnx (same place it rewrites manifest.xml). It needs no file
--      IO at runtime, so it cannot fail on a sandboxed or read-only install.
--      IF YOU RENAME OR REFORMAT THAT LINE, UPDATE THE sed IN main.yml TOO -
--      the workflow greps for it and fails the build if it is missing.
--
--   2. The installed manifest.xml, read from renoise.tool().bundle_path.
--      The legacy build carries <Id>org.lackluster.Paketti31</Id> and
--      <ApiVersion>5</ApiVersion>. This catches hand-rolled builds that never
--      went through CI, and is also what supplies the version string shown to
--      the user. Falls back to the bundle path itself if the file is
--      unreadable.
--
-- Either signal saying "legacy" is enough to warn.

-- CI-STAMPED LINE - see note 1 above. Do not reformat.
local PAKETTI_BUILD_FLAVOR = "3.54"

local PAKETTI_RELEASES_URL = "https://github.com/esaruoho/paketti/releases/latest"

-- Read <Tag>value</Tag> out of the installed manifest, or nil.
local function pakettiVersionGuardReadManifest()
  local path = nil
  local ok = pcall(function() path = renoise.tool().bundle_path end)
  if not ok or not path then return nil, nil end
  local xml = nil
  pcall(function()
    local f = io.open(path .. "manifest.xml", "r")
    if not f then return end
    xml = f:read("*a")
    f:close()
  end)
  return xml, path
end

-- Returns: is_legacy_build (boolean), build_version (string), how_detected (string)
function PakettiVersionGuardInspectBuild()
  local stamped_legacy = (PAKETTI_BUILD_FLAVOR == "3.1")
  local xml, path = pakettiVersionGuardReadManifest()

  local manifest_id, manifest_api, manifest_version = nil, nil, nil
  if xml then
    manifest_id = xml:match("<Id>%s*([^<]-)%s*</Id>")
    manifest_api = tonumber(xml:match("<ApiVersion>%s*(%d+)%s*</ApiVersion>"))
    manifest_version = xml:match("<Version>%s*([^<]-)%s*</Version>")
  end

  local manifest_legacy = false
  if manifest_id and manifest_id:find("Paketti31", 1, true) then manifest_legacy = true end
  if manifest_api and manifest_api <= 5 then manifest_legacy = true end

  -- Last resort: the install folder is named after the tool Id, so an
  -- unreadable manifest can still be worked around.
  local path_legacy = false
  if not manifest_legacy and path and path:find("Paketti31", 1, true) then
    path_legacy = true
  end

  local reasons = {}
  if stamped_legacy then table.insert(reasons, "build stamp") end
  if manifest_legacy then table.insert(reasons, "manifest") end
  if path_legacy then table.insert(reasons, "bundle path") end

  local is_legacy = (stamped_legacy or manifest_legacy or path_legacy)
  -- The manifest is the only place a real version string lives; when it could
  -- not be read, fall back to the stamp, and to "3.1" if we know it is legacy.
  local build_version = manifest_version or PAKETTI_BUILD_FLAVOR or "unknown"
  if is_legacy and not manifest_version and build_version == "3.54" then
    build_version = "3.1"
  end
  return is_legacy, build_version, table.concat(reasons, " + ")
end

-- True when the host Renoise is newer than what the legacy build targets.
-- Renoise 3.1 is API 5; 3.2 and up are API 6 or higher.
local function pakettiVersionGuardHostIsNewer()
  local api = renoise.API_VERSION or 0
  return api >= 6
end

function PakettiVersionGuardShowMismatchDialog(force)
  local is_legacy, build_version, how = PakettiVersionGuardInspectBuild()
  local host_newer = pakettiVersionGuardHostIsNewer()
  local renoise_version = renoise.RENOISE_VERSION or "unknown"

  if not force and not (is_legacy and host_newer) then return false end

  if not is_legacy then
    renoise.app():show_message(string.format(
      "Paketti v%s is the correct build for Renoise %s.", build_version, renoise_version))
    return false
  end

  local message = string.format(
    "You are running Paketti v3.1 - the build made for Renoise 3.1 - " ..
    "on Renoise %s.\n\n" ..
    "This is the wrong version of Paketti for your Renoise. Features will be " ..
    "missing or will misbehave, because this build is compiled against the " ..
    "older Renoise scripting API. Bugs you hit here are almost certainly this " ..
    "mismatch and not Paketti itself.\n\n" ..
    "Please install Paketti v3.54 instead:\n\n" ..
    "  1. Open the downloads page and download Paketti v3.54\n" ..
    "  2. Uninstall Paketti v3.1 first, in Renoise:\n" ..
    "     Tools > Tool Browser > Paketti 3.1 > Uninstall\n" ..
    "  3. Install the Paketti v3.54 .xrnx you downloaded\n\n" ..
    "Please do not run Paketti v3.1 on Renoise 3.5 and newer.\n\n" ..
    "%s",
    renoise_version, PAKETTI_RELEASES_URL)

  local choice = renoise.app():show_prompt(
    "Paketti: Wrong Version for This Renoise",
    message,
    {"Open Downloads Page", "Continue Anyway"})

  if choice == "Open Downloads Page" then
    pcall(function() renoise.app():open_url(PAKETTI_RELEASES_URL) end)
  end

  print(string.format(
    "Paketti Version Guard: legacy build (%s) detected on Renoise %s (API %s) - warned user.",
    tostring(how), tostring(renoise_version), tostring(renoise.API_VERSION)))
  return true
end

-- Shown once per Renoise session, on a one-shot timer rather than at load
-- time: a modal dialog raised while Renoise is still booting its tools can
-- block startup, and renoise.song() does not exist yet either.
local pakettiVersionGuardTimerFired = false

local function pakettiVersionGuardTick()
  if pakettiVersionGuardTimerFired then return end
  pakettiVersionGuardTimerFired = true
  pcall(function()
    if renoise.tool():has_timer(pakettiVersionGuardTick) then
      renoise.tool():remove_timer(pakettiVersionGuardTick)
    end
  end)
  pcall(function() PakettiVersionGuardShowMismatchDialog(false) end)
end

-- Only arm the timer when there is actually something to say, so the correct
-- build costs nothing at all.
do
  local is_legacy = false
  pcall(function() is_legacy = (PakettiVersionGuardInspectBuild()) end)
  if is_legacy and pakettiVersionGuardHostIsNewer() then
    pcall(function() renoise.tool():add_timer(pakettiVersionGuardTick, 2000) end)
  end
end

function PakettiVersionGuardShowStatus()
  PakettiVersionGuardShowMismatchDialog(true)
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:!Preferences:Check Renoise Version Compatibility",
  invoke=PakettiVersionGuardShowStatus}
