# H3Swift for Wander

This local Swift package contains the library sources from
[H3Swift 1.0.1](https://github.com/libardoram/H3Swift/tree/1.0.1), commit
`f7c2e092dfd8b070458ffc05f599836fc6b09d18`.
The vendored C library is [Uber H3 4.4.1](https://github.com/uber/h3/tree/v4.4.1).
All 46 files under `Sources/` are unchanged from that H3Swift commit.

## Manifest changes

- Remove `.unsafeFlags(["-w"])` from `Ch3`. Xcode rejects the remote product
  with this setting; compiler warnings are now visible.
- Keep only the `H3` library and its `H3` and `Ch3` targets. Examples and the
  upstream test target are not distributed in this copy.
- Preserve the supported platforms, C source list, public headers and internal
  header search path. Wander continues to use `import H3`.
- Define `M_PI` and `M_PI_2` with Darwin's double literals through standard
  `CSetting.define` entries. H3's guarded fallback definitions otherwise conflict
  with the imported Darwin module. Both upstream and Darwin literals represent
  the same binary64 values, `0x1.921fb54442d18p+1` and `0x1.921fb54442d18p+0`.
  This resolves the warnings without changing sources or suppressing diagnostics.

The Xcode project references `Vendor/H3Swift` by a relative path, so another
checkout uses the same sources without modifying a DerivedData cache.

## Licenses

- `LICENSE`: upstream H3Swift MIT license.
- `LICENSE-H3`: Apache 2.0 license from Uber H3 tag `v4.4.1`.
- `NOTICE-H3`: notice from the same Uber H3 tag.
- Existing copyright and license headers are preserved.

## Updating

Choose and document an explicit upstream version and commit before replacing
the sources. Preserve the licenses and notice, review upstream changes, and
compare the copied sources with that revision. Keep the library manifest free
of unsafe build flags. Validate the Xcode simulator and device builds and open
the map before accepting an update.

See `docs/plans/2026-10-07-corriger-dependance-h3.md` for the initial
integration and validation evidence.
