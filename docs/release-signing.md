# Signing XKeen releases

Release archives are signed with Minisign. The maintainer must:

1. Create and retain an offline Minisign key pair.
2. Store the private key as the `MINISIGN_SECRET_KEY` GitHub Actions secret.
3. Commit the corresponding one-line public key to
   `scripts/_xkeen/keys/xkeen.minisign.pub`.

The release workflow refuses to publish without the private-key secret and
uploads `xkeen.tar.gz.minisig` with the archive. Installations verify a
signature when both that file and the packaged public key are available.
Unsigned legacy releases warn in `verify_downloads: warn` (the default) and
fail in `strict`; `off` is an explicit escape hatch.
