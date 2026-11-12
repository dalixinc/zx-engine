# Atlantis in the browser

Branch `claudelet/dev`. Quartus's brief, item by item. No game code
changed.

Once GitHub Pages is on (the steps are at the end), it is here:

**https://dalixinc.github.io/zx-engine/play/**

`https://dalixinc.github.io/zx-engine/` forwards there too.

**Trigon**, the second game ([TRIGON.md](TRIGON.md)), has its own page,
`docs/play/trigon/index.html`, at
**https://dalixinc.github.io/zx-engine/play/trigon/**. It is the same
page with Trigon's title, colours and keys (option 1 asks for the code),
and it uses Atlantis's copy of JSSpeccy, one folder up: JSSpeccy finds
its worker, ROMs and tape loaders from its own script's address. `make
web` copies `build/trigon.sna` and `.tap` there and stamps their hashes
(`tools/webstamp.sh trigon docs/play/trigon`). `build.bat web` does
Atlantis only for now.

## 1. The page

`docs/play/index.html` is one plain page:

- the title, ATLANTIS;
- the emulator, behind a blue "Click to play" panel;
- the keys in a short table underneath;
- one line saying it runs in JSSpeccy 3 (GPL-3.0), with links to the
  licence and to the tape.

It picks the largest of 1x, 2x and 3x that fits the window: 3x on a
large monitor, 2x on a laptop, 1x on a phone.

| Action | Keys |
|---|---|
| start a game (menu) | `1` |
| 50 or 25 frames a second (menu) | `2` |
| swim | `Q` `A` `O` `P`, or `7` `6` `5` `8` |
| fire | `Space` or `0` |
| back to the menu | `Ctrl` + `P` |
| change speed while playing | `Ctrl` + `F` |
| the debug line | `Ctrl` + `S` |

JSSpeccy makes the PC's **Ctrl** the Spectrum's **Symbol Shift**. It
calls `preventDefault` on every key, so Ctrl + P, Ctrl + F and Ctrl + S go
to the game, not to the browser's print, find and save.

## 2. The emulator: JSSpeccy 3.2

- **Kept in the repo:** `docs/play/jsspeccy/` is the unmodified
  `jsspeccy` folder of the v3.2 release archive (about 450 KB), so the
  page needs no other site. It holds the script, the worker, the
  WebAssembly core, the ROMs and the tape-loader snapshots. Only the
  source map and the macOS clutter were left out.
- **Licence:** JSSpeccy is **GPL-3.0**, which allows this as long as
  the licence goes with it and the source is offered.
  - `COPYING` is the licence.
  - `SOURCE.md` gives the release, its SHA-256 and the source for
    exactly that version.
  - `jsspeccy.js.LICENSE.txt` covers the bundled JSZip (MIT or GPLv3).
  - The ROMs are Amstrad's, who allow them to be distributed with
    emulators.
  - Nothing of ours is linked into JSSpeccy. The page only calls it, so
    the game itself is not affected by the GPL.
- **Settings:**
  - 48K Spectrum;
  - zoom 1, 2 or 3 (see above);
  - `sandbox`, which hides "open a file";
  - started by the click, which is what lets the sound play (item 4).

## 3. The tape, and why the page plays the snapshot

The brief: use the full tape if JSSpeccy loads it instantly, otherwise
the quick one. **JSSpeccy 3.2 can't load our full tape instantly**:

- **Instant loading fails.** After "Program: atlantis" it stops with
  `5 Out of screen, 0:1`. The same happens with the screen or the POKE
  taken out of the loader, so neither of those is the cause.
- **The tape itself is fine.** JSSpeccy's own loader snapshot
  (`tape_48.szx`) plus our tape, loaded with traps in Fuse, reaches the
  menu.
- **Real-time loading works**, and the loading screen draws in
  properly, stripes and all. But the whole tape takes about two and a
  half minutes.
- **The Engine Demo 1 tape loads instantly** in JSSpeccy.

So this looks like a JSSpeccy problem with this particular tape. I
didn't chase it further.

The quick one is the game's own snapshot, `atlantis.sna`, which `make`
already builds. JSSpeccy opens it at once. The snapshot starts with the
loading screen in screen memory, and start-up now holds it there for
two seconds before the menu (`CFG_SCREEN_PAUSE`, any key skips it;
[STORY-AND-LIVES.md](STORY-AND-LIVES.md)): before that it was cleared
after half a second. The tape is beside it, `docs/play/atlantis.tap`,
linked on the page for anyone who wants it in another emulator or on a
real Spectrum.

**Updating the site** is one command and a push:

```
make web                    # Linux: rebuilds, copies atlantis.sna and .tap to docs/play/
build.bat web               # Windows: the same
git add docs/play/atlantis.sna docs/play/atlantis.tap docs/play/index.html
git commit -m "Update the web build." && git push
```

`build/` stays out of git. The two copies in `docs/play/` are committed,
because GitHub Pages serves `docs/` from git.

**Each build has its own address.** GitHub Pages tells browsers to keep
a file for ten minutes (`cache-control: max-age=600`), and the page
fetches the snapshot from its script, so after an update a browser could
go on playing the last build for up to ten minutes, even after a hard
refresh. So `make web` also stamps the first 8 hex digits of each file's
SHA-1 into `index.html`: the snapshot is opened as
`atlantis.sna?v=<hash>&type=.sna` and the tape's link is
`atlantis.tap?v=<hash>`. A new build is a new address, fetched at once;
the server ignores the query. The `&type=.sna` is there because JSSpeccy
picks a file's type by how the whole address ends
(`getFileOpener(url).endsWith(".sna")`): `atlantis.sna?v=<hash>` alone
would be "Unrecognised file type". The stamp is `tools/webstamp.sh` (from
the Makefile) and `tools/webstamp.ps1` (from `build.bat`, through
Windows PowerShell); both rewrite only those two addresses, so running
`make web` again changes nothing.

## 4. Browsers

- **Sound:** browsers only allow sound after a click on the page.
  JSSpeccy starts its sound when it starts, so the page doesn't create
  it at load: the "Click to play" panel creates and starts it inside
  the click.
- **Chrome (Chromium): tested.** This machine has Vivaldi, which uses
  Chrome's engine. Under a virtual display, with the page served
  locally:
  - the panel came up;
  - a click loaded the emulator, the ROMs and the snapshot, and showed
    the menu;
  - `1` started the game, `Q` swam up and `Space` fired;
  - the `.wasm` file is served as `application/wasm`, as GitHub Pages
    does.

  I can't hear, so whether the sound plays was not checked by ear.
- **Firefox: not tested.** There is no Firefox on this machine, and
  installing a test browser was blocked in this session. JSSpeccy 3 is
  written for current browsers, so it should work. Please open the page
  in Firefox once it's live and check that the click gives sound.
- **Phones:** on a coarse-pointer or touch device the page shows an
  on-screen D-pad, a holdable Fire button, Start (sends `1`), Skip,
  and a letters pad for typing a code. You can also drag on the
  picture to swim. Desktop and keyboard play are unchanged: the
  controls are not shown when the primary pointer is a mouse. Add the
  page to the Home Screen for a full-screen shortcut. Tested in a
  mobile viewport on a desktop browser, not yet on a real phone.

## 5. Nothing in the game changed

- **What changed:** the page, the emulator files, the two copies, the
  `make web` and `build.bat web` targets, `.nojekyll`, and the docs.
- **Checks:** Engine Demo 1 is byte-identical. The game's snapshot and
  tape are the normal build, unchanged.

## 6. Turning on GitHub Pages (after this is merged into main)

1. On GitHub, open **dalixinc/zx-engine**.
2. Click **Settings** (the tab on the right, at the top of the
   repository).
3. In the left-hand menu, under **Code and automation**, click
   **Pages**.
4. Under **Build and deployment**, set **Source** to **Deploy from a
   branch**.
5. Under **Branch**, choose **main**. In the folder box next to it,
   choose **/docs**. Click **Save**.
6. Wait a minute or two. The Pages screen then shows "Your site is live
   at https://dalixinc.github.io/zx-engine/". The **Actions** tab shows
   the deploy while it runs.
7. Open **https://dalixinc.github.io/zx-engine/play/**, click "Click to
   play", and press `1`.

A few things to know about the site:

- **Plain files.** `docs/.nojekyll` tells Pages to serve the files
  exactly as they are. Without it, Pages would run Jekyll over the
  folder, which can fail on the brace sequences in the docs.
- **Everything in `docs/` is public**, including the PDFs and zips.
  The repository is public already, so nothing new is exposed.
- **Updates go live by themselves.** After any later push to main that
  changes `docs/`, Pages redeploys in a minute or two.

## Files

| File | What |
|---|---|
| `docs/play/index.html` | the page |
| `docs/play/phone.js`, `docs/play/phone.css` | on-screen touch controls, only on a phone |
| `docs/play/manifest.webmanifest`, `docs/play/icons/` | Add to Home Screen, and the I7 icon |
| `docs/play/atlantis.sna` | what the page plays (`make web`) |
| `docs/play/atlantis.tap` | the tape, to download (`make web`) |
| `docs/play/trigon/` | Trigon's page, `trigon.sna`, `trigon.tap` and its own manifest (`make web`) |
| `tools/webstamp.sh`, `tools/webstamp.ps1` | stamp each file's hash into the page's addresses (`make web`, `build.bat web`) |
| `docs/play/jsspeccy/` | JSSpeccy 3.2, with `COPYING` and `SOURCE.md` |
| `docs/index.html` | sends the site's root to `play/` |
| `docs/.nojekyll` | serve `docs/` as plain files |
| `Makefile`, `build.bat` | the `web` target |
| `README.md`, `CLAUDE.md` | where the web version is |
