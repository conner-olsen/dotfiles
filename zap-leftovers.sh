#!/bin/zsh
# Finds files left behind by apps that are no longer installed, using the cleanup ("zap") lists of
# Homebrew casks, however the app was originally installed. Lists them, then on confirmation
# removes them with Homebrew's own `brew uninstall --cask --zap --force`.
#
# A cask is only offered when all of these hold:
#   - its app is confirmed gone (no install target on disk, no matching package receipt);
#   - there is proof the app was on this Mac: a record names it (Homebrew's download cache,
#     /Library/Receipts/InstallHistory.plist, or a `brew install` in shell history), or a leftover
#     file carries one of its unique app IDs (e.g. com.microsoft.Word). Generic names like
#     ~/Library/Caches/copilot are not proof;
#   - none of its cleanup paths overlaps a file of an app still installed or of macOS itself,
#     because Homebrew's zap removes every path on the cask's list, not just the ones shown here.

set -e
command -v brew >/dev/null || { echo "Homebrew is required."; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Fetching Homebrew's cask list..."
curl -fsSL https://formulae.brew.sh/api/cask.json -o "$tmp/cask.json"
brew list --cask -1 > "$tmp/installed.txt" 2>/dev/null || true
pkgutil --pkgs > "$tmp/receipts.txt"

echo "Scanning for leftovers..."
python3 -I - "$tmp/cask.json" "$tmp/installed.txt" "$tmp/receipts.txt" "$(brew --prefix)" \
  "$(brew --cache)" "$tmp/casks.txt" "$tmp/paths.txt" <<'PY'
import glob, json, os, plistlib, re, subprocess, sys

casks_json, installed_txt, receipts_txt, prefix, brew_cache, out_casks, out_paths = sys.argv[1:]
home = os.path.expanduser("~")
installed = set(open(installed_txt).read().split())
receipts = open(receipts_txt).read().split()

def as_list(v):
    return [v] if isinstance(v, str) else list(v or [])

def expand(p):
    p = p.replace("$HOMEBREW_PREFIX", prefix).replace("$APPDIR", "/Applications")
    return os.path.normpath(os.path.expanduser(p)) if p.startswith(("~", "/")) else None

def stanza_values(artifacts, keys, kinds=("uninstall", "zap")):
    for a in artifacts:
        for kind in kinds:
            for st in a.get(kind, []):
                if isinstance(st, dict):
                    for key in keys:
                        yield from as_list(st.get(key))

def cleanup_paths(artifacts):
    return {e for p in stanza_values(artifacts, ("trash", "delete")) if (e := expand(p))}

# Apple's own data stores (Photos, Mail, Messages, Safari, iCloud Drive, ...) and the Music, Movies and
# Pictures folders. Merely looking makes macOS ask for permission, so these are never touched.
PRIVATE = re.compile(r"\.photoslibrary(/|$)|com\.apple\.|^~/(Music|Movies|Pictures)(/|$)|^~/Library/(Mail|Messages|Safari|SafariTechnologyPreview"
                     r"|Calendars|Reminders|Suggestions|HomeKit|IdentityServices|Mobile Documents|CloudStorage"
                     r"|Application Support/(AddressBook|CallHistoryDB|Knowledge|MobileSync))(/|$)")

def private(p):
    return bool(PRIVATE.search(p.replace(home, "~", 1)))

def existing(pattern):
    if private(pattern):
        return []
    return glob.glob(pattern) if glob.has_magic(pattern) else ([pattern] if os.path.lexists(pattern) else [])

def regexes(artifacts):
    for v in stanza_values(artifacts, ("pkgutil",)):
        try:
            yield re.compile(v)
        except re.error:
            pass

# --- What is on this Mac -------------------------------------------------------------------------

bundle_ids = set()
apps = set()
for d in ("/Applications", home + "/Applications", "/System/Applications"):
    apps.update(glob.glob(d + "/*.app") + glob.glob(d + "/*/*.app") + glob.glob(d + "/*/*/*.app"))
try:
    apps.update(subprocess.run(["mdfind", "kMDItemContentType == com.apple.application-bundle"],
                               capture_output=True, text=True, timeout=60).stdout.split("\n"))
except Exception:
    pass
for app in filter(None, apps):
    try:
        with open(app + "/Contents/Info.plist", "rb") as f:
            if (bid := plistlib.load(f).get("CFBundleIdentifier")):
                bundle_ids.add(bid.lower())
    except Exception:
        pass

# --- Records of past installs --------------------------------------------------------------------

cached = {n.split("--")[0] for n in os.listdir(os.path.join(brew_cache, "Cask"))} \
    if os.path.isdir(os.path.join(brew_cache, "Cask")) else set()

history_names, history_pkgs = set(), []
try:
    with open("/Library/Receipts/InstallHistory.plist", "rb") as f:
        for e in plistlib.load(f):
            if e.get("displayName"):
                history_names.add(e["displayName"].lower())
            history_pkgs += e.get("packageIdentifiers", [])
except Exception:
    pass

shell_history = ""
for h in ("~/.zsh_history", "~/.bash_history"):
    try:
        shell_history += open(os.path.expanduser(h), errors="ignore").read()
    except OSError:
        pass
brew_installs = set()
for m in re.finditer(r"brew\s+(?:re)?install\b([^\n;&|]*)", shell_history):
    brew_installs.update(w for w in m.group(1).split() if not w.startswith("-"))

# --- Classify every cask -------------------------------------------------------------------------

# Reverse-DNS app IDs (com.vendor.App): first part letters only, so version strings like x-1.2.3 don't count.
ID = re.compile(r"(?<![A-Za-z0-9.-])[a-z]{2,10}\.[a-z][a-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9.-]*", re.I)

def app_ids(artifacts, paths):
    ids = set()
    for v in stanza_values(artifacts, ("quit", "launchctl", "signal")):
        if isinstance(v, str):
            ids.add(v)
    for p in paths:
        ids.update(ID.findall(os.path.basename(p)))
    ids = {i.rstrip(".*-").lower() for i in ids}
    return {i for i in ids if i.count(".") >= 2 and not i.startswith("com.apple.")}

def targets(artifacts):
    return [e for a in artifacts if isinstance(a.get("target"), str) and (e := expand(a["target"]))]

def is_present(c, arts):
    if c["token"] in installed:
        return True
    tg, rx = targets(arts), list(regexes(arts))
    if any(os.path.lexists(t) for t in tg):
        return True
    if any(r.fullmatch(p) for r in rx for p in receipts):
        return True
    return not tg and not rx  # nothing checkable: can't confirm it's gone

def evidence(c, arts, found, ids):
    token = c["token"]
    if token in cached:
        return "Homebrew download cache"
    if token in brew_installs:
        return "brew install in shell history"
    names = {os.path.basename(t)[:-4].lower() for t in targets(arts) if t.endswith(".app")}
    if names & history_names or any(r.fullmatch(p) for r in regexes(arts) for p in history_pkgs):
        return "InstallHistory.plist"
    for p in found:
        low = os.path.basename(p).lower()
        for i in ids:
            if i in low:
                return f"file named with its app ID {i}"
    return None

casks = json.load(open(casks_json))
protected, gone = set(), []
for c in casks:
    arts = c.get("artifacts", [])
    paths = cleanup_paths(arts)
    if is_present(c, arts):
        protected.update(paths)
    else:
        gone.append((c, arts, paths))
protected_existing = {e for q in protected for e in (existing(q) or [q])}

def overlaps(p, q):
    return p == q or p.startswith(q + "/") or q.startswith(p + "/")

def conflict(p):
    low = p.lower()
    if "com.apple." in low or low.startswith((home.lower() + "/library/safari", "/system/")):
        return True
    if any(bid in low for bid in bundle_ids):
        return True
    return any(overlaps(p, q) for q in protected_existing)

def size(p):
    if "/Library/Containers/" in p or "/Library/Group Containers/" in p:
        return None  # reading inside another app's container triggers a macOS privacy prompt
    try:
        if not os.path.isdir(p) or os.path.islink(p):
            return os.lstat(p).st_blocks * 512
        total = 0
        for root, _, files in os.walk(p):
            for f in files:
                try: total += os.lstat(os.path.join(root, f)).st_blocks * 512
                except OSError: pass
        return total
    except OSError:
        return None

def human(n):
    if n is None: return "   ?"
    for unit in ("B", "K", "M", "G"):
        if n < 1024: return f"{n:4.0f}{unit}"
        n /= 1024
    return f"{n:4.1f}T"

offered, skipped = [], []
for c, arts, paths in sorted(gone, key=lambda x: x[0]["token"]):
    found = sorted({e for p in paths for e in existing(p)})
    if not found:
        continue
    why = evidence(c, arts, found, app_ids(arts, paths))
    if not why:
        continue
    if any(private(p) for p in paths) or any(conflict(e) for p in paths for e in (existing(p) or [p])):
        skipped.append(c["token"])
    else:
        offered.append((c["token"], why, found))

total = 0
for token, why, found in offered:
    print(f"\n{token}  ({why})")
    for p in found:
        s = size(p); total += s or 0
        print(f"  {human(s)}  {p.replace(home, '~', 1)}")
if skipped:
    print("\nSkipped, because their cleanup lists touch files of installed apps or macOS's own data:")
    print("  " + ", ".join(skipped))
print(f"\n{len(offered)} app{'' if len(offered) == 1 else 's'} with leftovers, {human(total).strip()} total"
      " (sizes inside app containers not counted).")
open(out_casks, "w").write("\n".join(t for t, _, _ in offered))
open(out_paths, "w").write("\n".join(p for _, _, f in offered for p in f))
PY

casks=(${(f)"$(<$tmp/casks.txt)"})
(( ${#casks} )) || { echo "Nothing to remove."; exit 0; }

read "reply?Remove all of the above with brew's zap? Files are moved to the Trash or deleted; system files ask for your password. [y/N] "
[[ $reply == [yY] ]] || { echo "Nothing removed."; exit 0; }
brew uninstall --cask --zap --force "${casks[@]}" || true

left=()
while IFS= read -r p; do [[ -e $p || -L $p ]] && left+=("$p"); done < "$tmp/paths.txt"
if (( ${#left} )); then
  echo "\nThese could not be removed (macOS protects app containers); drag them to the Trash in Finder:"
  printf '  %s\n' "${left[@]}"
fi
echo "Done. Empty the Trash to free the space."
