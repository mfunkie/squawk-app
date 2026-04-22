# Post-Notarization Release Checklist

Once you've enrolled in the Apple Developer Program and have a Developer ID Application certificate, follow this guide to ship a properly signed + notarized build so users can double-click the DMG without Gatekeeper warnings.

## Prerequisites

- [ ] Enrolled in the Apple Developer Program ($99/yr)
- [ ] "Developer ID Application" certificate installed in login keychain
- [ ] An app-specific password for your Apple ID (create at https://appleid.apple.com → Sign-In and Security → App-Specific Passwords)
- [ ] `xcrun`, `xcodebuild`, `notarytool`, `stapler` available (all ship with Xcode)

Verify the cert is present:

```bash
security find-identity -v -p codesigning
# Should list an identity like: "Developer ID Application: Mark Funk (HGAJ9C9V68)"
```

## One-Time Setup: Keychain Profile for notarytool

Store credentials once so `notarize.sh` can submit without prompting:

```bash
xcrun notarytool store-credentials squawk-notarize \
    --apple-id "mfunk86@gmail.com" \
    --team-id "HGAJ9C9V68" \
    --password "APP-SPECIFIC-PASSWORD-HERE"
```

The profile name `squawk-notarize` matches the default `KEYCHAIN_PROFILE` in `scripts/notarize.sh`.

## Release Flow

From a clean `main` with all changes committed:

### 1. Bump version

Edit `MARKETING_VERSION` in `Squawk/Squawk.xcodeproj/project.pbxproj` (and bump `CURRENT_PROJECT_VERSION` if you want a new build number). Commit the bump.

### 2. Archive + export

```bash
./scripts/build.sh
```

This now succeeds end-to-end because `ExportOptions.plist` uses `developer-id`, which requires the Developer ID cert you just installed. Output:

- `build/Squawk.xcarchive` — Xcode archive
- `build/export/Squawk.app` — signed, hardened-runtime app ready for notarization

Sanity check the signature:

```bash
codesign -dvv build/export/Squawk.app
# Authority line should start with "Developer ID Application: ..."
```

### 3. Notarize + staple

```bash
./scripts/notarize.sh
```

This zips the app, submits to Apple, waits for the result, then staples the ticket to the `.app` bundle. Typical turnaround is 1-5 minutes. If it fails, grab the submission ID from the output and run:

```bash
xcrun notarytool log <submission-id> --keychain-profile squawk-notarize
```

to see what the notary service rejected (usually missing hardened runtime flags or an unsigned nested binary).

Verify stapling:

```bash
xcrun stapler validate build/export/Squawk.app
spctl --assess --type execute --verbose build/export/Squawk.app
# Should print: "accepted, source=Notarized Developer ID"
```

### 4. Repackage DMG (notarized)

The DMG needs to wrap the stapled `.app`, so rebuild it after stapling:

```bash
rm -f build/Squawk.dmg
./scripts/create-dmg.sh
```

Optionally notarize the DMG itself (nice-to-have, but the stapled `.app` inside is what Gatekeeper checks):

```bash
xcrun notarytool submit build/Squawk.dmg \
    --keychain-profile squawk-notarize --wait
xcrun stapler staple build/Squawk.dmg
```

### 5. Also rebuild the zip

```bash
cd build/export && ditto -c -k --keepParent Squawk.app ../Squawk.zip && cd -
```

### 6. Tag and release

```bash
VERSION=vX.Y.Z
git tag -a "$VERSION" -m "Squawk $VERSION"
git push origin "$VERSION"

gh release create "$VERSION" \
    build/Squawk.dmg \
    build/Squawk.zip \
    --title "Squawk $VERSION" \
    --notes-file docs/release-notes/$VERSION.md   # or --notes "..."
```

### 7. Update the README

Remove the "right-click → Open" / `xattr` workaround from `README.md` — users no longer need it. Also remove the Gatekeeper section from any release notes template you copy forward.

## Post-Release Verification

On a clean test Mac (or a fresh user account):

- [ ] Download the DMG from the GitHub release page
- [ ] Double-click to mount, drag to Applications
- [ ] Launch from Applications — no Gatekeeper prompt, no right-click needed
- [ ] Confirm `spctl --assess` still passes after copy

## Retroactively Fixing v1.0.0

If you want v1.0.0 users to get a notarized build without bumping the version:

1. Run steps 2-5 above on the v1.0.0 commit (`git checkout v1.0.0`, build, notarize, repackage)
2. Delete and re-upload the release assets:
   ```bash
   gh release delete-asset v1.0.0 Squawk.dmg Squawk.zip
   gh release upload v1.0.0 build/Squawk.dmg build/Squawk.zip
   ```
3. Edit the release notes to remove the Gatekeeper workaround section

Alternatively, just ship v1.0.1 and point people to it.

## Why the v1.0.0 Build Wasn't Notarized

At release time only an "Apple Development" certificate was in the keychain. That cert can sign apps for local development but cannot be used for `developer-id` export or notarization, so `scripts/build.sh` failed at the export step and the `.app` was copied directly out of the archive. The binary was validly signed but Gatekeeper flags any non-notarized download, which is why the v1.0.0 release notes include the right-click workaround.
