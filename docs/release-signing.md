# Signing XKeen releases

Release archives are signed with Minisign. The maintainer must:

1. Create and retain an offline Minisign key pair.
2. Store the private key as the `MINISIGN_SECRET_KEY` GitHub Actions secret.
3. Commit the corresponding one-line public key to
   `scripts/_xkeen/keys/xkeen.minisign.pub`.

The release workflow permits unsigned legacy-compatible releases when the
private-key secret is absent. Once `MINISIGN_SECRET_KEY` is configured, it
refuses to sign or publish unless the public-key file above is already
committed. TODO for the maintainer: generate the key pair and commit its
public half before enabling the secret.

Installations verify a signature when both that file and the packaged public
key are available. `verify_downloads` defaults to `warn`: third-party
downloads are checked against an independent upstream SHA-256 reference when
it is available. If a binary was obtained through a mirror while that
reference is unavailable, installation continues for compatibility but emits
a prominent “installed WITHOUT integrity verification” warning. `strict`
fails in that case; `off` is an explicit escape hatch.
