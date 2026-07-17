# Mastodon Bird UI vendoring notes

This directory is vendored from
[`rollecode/mastodon-bird-ui`](https://github.com/rollecode/mastodon-bird-ui).

- Installed version: 4.0.0
- Source commit: `72da9155849f4cc6e736d4bfd3b676cd7ee08919`
- Mastodon target: 4.6.x
- Accessible variations: not installed
- Server default: Mastodon's default theme (Bird UI remains selectable)

Update procedure:

1. Check out the desired upstream Bird UI revision.
2. Run `scripts/install-to-mastodon.sh --path /home/mastodon/live` from that checkout.
3. Answer “no” to accessible variations and to making Bird UI the server default,
   unless the deployment policy has intentionally changed.
4. Update the version and source commit above, retain `LICENSE.md`, and run the
   Mastodon style/build checks.

The selectable entry point is `../mastodon-bird-ui-auto.scss`; it follows each
user's light/dark color-scheme preference as required by Mastodon 4.6.
