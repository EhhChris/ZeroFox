// autoconfig.js — installed to <app>/defaults/pref/autoconfig.js
// Instructs Firefox to load mozilla.cfg from the application directory.
// pref() here configures the autoconfig system itself; these are not lockable.
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
