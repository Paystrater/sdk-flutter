# Publishing paystrater_flutter

CI publishes every release from a version tag on `main`, with pub.dev's automated publishing. No personal credentials live in GitHub, and nothing goes out until a maintainer approves the job in GitHub. A version on pub.dev can't be changed or deleted afterwards, so test first.

## Release in five steps

**1. Set the version on `dev`.** Change `version` in `pubspec.yaml`, using `0.1.0-dev.2` for a test release, and add its notes at the top of `CHANGELOG.md`. Use patch for fixes, minor for new features and major for breaking changes. The first stable release is `1.0.0`.

**2. Check it.**

```bash
flutter analyze && flutter test && dart pub publish --dry-run
```

**3. Merge.** Commit, push `dev`, and merge it into `main` by pull request once CI passes.

```bash
git add -A
git commit -m "feat: <what changed>"
git push origin dev
gh pr create --base main --head dev --fill
gh pr merge --merge   # once CI is green
```


**4. Tag `main`.** The tag must be `v` plus the version in `pubspec.yaml`.

```bash
git checkout main && git pull && git tag v0.1.0-dev.2 && git push origin v0.1.0-dev.2
```

**5. Approve.** Approve the **Publish to pub.dev** job in GitHub. It runs the tests, checks the tag matches `pubspec.yaml`, and publishes. The version then appears on the package's page on pub.dev.

There is no `latest` tag to move: pub.dev has no dist-tags. `flutter pub add paystrater_flutter`, which setups and the docs use, takes the newest stable version, or the newest pre-release while no stable version exists. After `1.0.0`, a `-dev` release is only installed by someone who asks for it.

Before the first stable release, test a `dev` version on staging with test keys (`pk_test_…` and a payment created on `https://staging-api.paystrater.com`) on an Android and an iOS device.

```bash
cd example && flutter run --dart-define=PAYSTRATER_PK=pk_test_… --dart-define=PAYMENT_ID=rcv_…
```

## When the API changes

There is no types script here: the Dart models in `lib/src/models.dart` and the calls in `lib/src/client.dart` are written by hand, and the shared test vectors keep them in step with `@paystrater/react`. When the Developer API changes:

1. Follow it in `sdk-react` first (`npm run types`, plus `test/vectors/core.json` if the core's behaviour changed), and merge it.
2. Copy the vectors here and update the models and client to match:

```bash
tool/sync_vectors.sh            # copies ../sdk-react/test/vectors/core.json
tool/sync_vectors.sh --check    # what CI runs: fails while the copy differs
flutter analyze && flutter test
git add test/vectors lib && git commit -m "feat: follow the API's <change>"
```

## If a release fails

| What happened                        | What to do                                                                                                             |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| The tag doesn't match `pubspec.yaml` | Fix the version, merge, and push a new tag. Don't move a tag that has already been pushed                              |
| A check fails in the job             | Fix it, merge, and release the next version number                                                                     |
| pub.dev rejects the upload           | Check the Admin tab settings below. The repository and tag pattern must match exactly                                  |
| A bad version went live              | Publish a fixed version, then mark the bad one as retracted on the package's Admin tab. pub.dev allows this for 7 days |

## One-time setup

1. **Publisher.** Create a verified publisher for `paystrater.com` on pub.dev (pub.dev → Create publisher), verified through Google Search Console with a DNS TXT record.
2. **First version.** pub.dev only allows automated publishing for a package that already exists, so publish once by hand from a clean checkout of `main`, with no tag: run `dart pub publish --dry-run`, then `dart pub publish`. Then move the package to the `paystrater.com` publisher on its Admin tab.
3. **Automated publishing.** On the package's Admin tab, choose "Enable publishing from GitHub Actions" and enter repository `Paystrater/sdk-flutter` and tag pattern `v{{version}}`. Turn on "Require GitHub Actions environment" with `pub.dev`.
4. **GitHub environment.** In Settings → Environments, create `pub.dev`, add yourself as a required reviewer, and limit it to the branch `main` and the tag pattern `v*`.
5. **Protect the repository.** Add a ruleset for `main` that requires a pull request and passing CI and blocks force pushes and deletion, and one for `v*` tags that only admins can bypass. Turn on secret scanning with push protection, Dependabot alerts and private vulnerability reporting.
6. **CodeQL.** Choose the advanced setup, which is `.github/workflows/codeql.yml`, and keep CodeQL's default setup off, because GitHub rejects this workflow's results while it's on.
7. **Licence and contact.** Confirm the licence (MIT) and the support email shown on pub.dev.

## Commit messages

This repository is public, so write each message for a stranger reading the history.

```
<type>: <what changed, in the imperative, under 72 characters>

Optional body explaining why, not how.
```

Types are `feat`, `fix`, `docs`, `test`, `refactor`, `ci`, `build` and `chore`. For a breaking change, write `feat!:` and describe it in the body. Give pull requests a title in the same format, because it becomes the merge's description.

- `fix: stop polling after a final payment status`
- `ci: scan the plugin's Kotlin and Swift with CodeQL`
- `docs: explain the release steps`

Keep out internal documents, customer details, keys and other companies' names.

## What CI checks

- **CI workflow** (every push and pull request): `dart format`, `flutter analyze`, `flutter test`, the shared vectors against `@paystrater/react`'s copy, `pana` for full pub points, and `dart pub publish --dry-run`.
- **CodeQL workflow** (pull requests, pushes to `main` and weekly): builds the example app for Android and iOS and scans the plugin's Kotlin and Swift. CodeQL has no Dart support. The iOS job takes about 20 minutes.
- **Publish workflow** (a `v*` tag): the tests, that the tag matches `pubspec.yaml`, then `dart pub publish --force` with the GitHub OIDC token.

## What is in the package

Dart only, plus a few lines of Kotlin and Swift for opening links and the share sheet. `pubspec.yaml` depends on the Flutter SDK alone. v1 supports Android and iOS; Flutter web apps use the hosted checkout.

## CI and sdk-react

CI reads the public `sdk-react` repository to check the shared code against it. If `sdk-react` is ever made private, add the Actions secret `SDK_REACT_READ_TOKEN` here (read-only Contents on `Paystrater/sdk-react`).
