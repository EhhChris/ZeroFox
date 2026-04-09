// user.js — ZeroFox hardened preference overrides
// This file is copied into the Firefox profile directory on launch by zerofox-launch.sh.
// Preferences here are enforced every startup (unlike prefs.js which can be overwritten).
//
// NOTE: The heaviest disk-avoidance is done at the launch level by mounting a ramdisk
// for the profile directory (see zerofox-launch.sh). These prefs complement that approach.

// ── Disk cache: all off, memory cache only ────────────────────────────────────
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.disk.smart_size.enabled", false);
user_pref("browser.cache.disk.capacity", 0);
user_pref("browser.cache.disk.max_entry_size", 0);
user_pref("browser.cache.offline.enable", false);
user_pref("browser.cache.offline.capacity", 0);
// Memory cache: keep enabled, let Firefox auto-size based on available RAM.
// -1 = auto (Firefox typically uses ~256 MB on a system with 16 GB RAM, scales up/down).
// This only affects the HTTP resource cache (JS/CSS/images between requests), NOT per-tab
// RAM — tabs can still consume as much memory as the page requires.
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", -1);

// ── Downloads: block all to disk ─────────────────────────────────────────────
// Policy sets PromptForDownloadLocation false; patch 004 enforces the actual block.
// These prefs are belt-and-suspenders.
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.download.forbid_open_with", true);
user_pref("browser.download.always_ask_before_handling_new_types", true);
user_pref("browser.download.manager.retention", 0);   // Don't retain download history
user_pref("browser.download.start_downloads_in_tmp_dir", false);
user_pref("browser.helperApps.deleteTempFileOnExit", true);

// ── Private browsing: always on ───────────────────────────────────────────────
// Private browsing mode keeps history, form data, cookies in memory only.
// The ramdisk profile handles the rest; this ensures Firefox itself doesn't
// write session/history DBs to the (ramdisk) profile in non-ephemeral form.
user_pref("browser.privatebrowsing.autostart", true);

// ── Session restore: disabled ─────────────────────────────────────────────────
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.sessionstore.max_windows_undo", 0);
user_pref("browser.sessionstore.interval", 2147483647); // Effectively disable writes

// ── Screensharing ─────────────────────────────────────────────────────────────
user_pref("media.getusermedia.screensharing.enabled", false);
user_pref("media.getusermedia.browser.enabled", false);
user_pref("media.getusermedia.window.focus_source.enabled", false);

// ── Developer tools ───────────────────────────────────────────────────────────
// Belt-and-suspenders alongside DisableDeveloperTools policy and patch 008.
user_pref("devtools.policy.disabled", true);
user_pref("devtools.chrome.enabled", false);
user_pref("devtools.debugger.remote-enabled", false);
user_pref("devtools.debugger.prompt-connection", false);

// ── Clipboard ─────────────────────────────────────────────────────────────────
user_pref("dom.allow_cut_copy", false);
user_pref("dom.event.clipboardevents.enabled", false);

// ── Screenshots (built-in) ────────────────────────────────────────────────────
user_pref("extensions.screenshots.disabled", true);

// ── WebRTC (prevents IP leaks, also needed for screenshare) ───────────────────
user_pref("media.peerconnection.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("media.peerconnection.ice.proxy_only", true);

// ── Fingerprinting resistance ─────────────────────────────────────────────────
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);

// ── Tracking protection ───────────────────────────────────────────────────────
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// ── Network: reduce prefetch/speculation ─────────────────────────────────────
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.prefetch-next", false);
user_pref("network.predictor.enabled", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.proxy.socks_remote_dns", true);

// ── Geolocation ───────────────────────────────────────────────────────────────
user_pref("geo.enabled", false);

// ── Misc: no disk-touching features ──────────────────────────────────────────
user_pref("browser.formfill.enable", false);
user_pref("signon.rememberSignons", false);
user_pref("extensions.formautofill.available", "off");
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("places.history.enabled", false);          // No history DB writes
