# Repository index format (version 1)

A repository is a single JSON document served over HTTP(S). The app fetches it
whenever the user adds a source or pulls to refresh. There is no server-side
logic required — any static host (GitHub Pages, S3, nginx, a `python -m
http.server`, …) works.

The top level is an object:

| Field           | Type     | Required | Notes                                            |
| --------------- | -------- | -------- | ------------------------------------------------ |
| `formatVersion` | number   | yes      | Currently `1`.                                   |
| `name`          | string   | yes      | Shown as the source name if the user leaves it blank. |
| `description`   | string   | no       | Free text.                                       |
| `homepage`      | string   | no       | Repository website.                              |
| `mirrors`       | string[] | no       | Alternate index URLs.                            |
| `lastUpdated`   | string   | no       | ISO-8601 timestamp; the generator sets it.       |
| `apps`          | object[] | yes      | The apps in this repository.                     |

A bare JSON array of apps is also accepted for convenience, but the object form
is preferred because it can carry repository metadata.

## App object

| Field          | Type     | Required | Notes                                                   |
| -------------- | -------- | -------- | ------------------------------------------------------- |
| `id`           | string   | yes      | Android `applicationId`; unique across the repo.        |
| `name`         | string   | yes      | Display name.                                           |
| `summary`      | string   | no       | One line shown in lists.                                |
| `description`  | string   | no       | Markdown-ish long description.                          |
| `developer`    | string   | no       |                                                         |
| `license`      | string   | no       | SPDX id preferred (`MIT`, `Apache-2.0`, …).             |
| `categories`   | string[] | no       | Drives the category filter chips.                       |
| `tags`         | string[] | no       | Free-form; searched along with name and developer.      |
| `icon`         | string   | no       | URL to a square image.                                  |
| `screenshots`  | string[] | no       | URLs shown as a horizontal strip.                       |
| `homepage`     | string   | no       |                                                         |
| `sourceCode`   | string   | no       |                                                         |
| `issueTracker` | string   | no       |                                                         |
| `donate`       | string   | no       |                                                         |
| `releases`     | object[] | yes      | At least one; the highest `versionCode` is the latest.  |

## Release object

| Field             | Type   | Required | Notes                                                 |
| ----------------- | ------ | -------- | ----------------------------------------------------- |
| `versionName`     | string | yes      | User-visible version, e.g. `1.2.0`.                   |
| `versionCode`     | number | yes      | Must strictly increase between releases.              |
| `channel`         | string | no       | `stable` (default), `beta`, `alpha`.                  |
| `url`             | string | yes      | Direct link to the signed `.apk`.                     |
| `size`            | number | no       | Bytes; used for display and download progress.        |
| `sha256`          | string | no       | If set, verified after download.                      |
| `minSdkVersion`   | number | no       |                                                       |
| `targetSdkVersion`| number | no       |                                                       |
| `added`           | string | no       | ISO date.                                             |
| `changelog`       | string | no       | Shown under the version.                              |

## Example

See [`samples/example-repo.json`](../samples/example-repo.json).

## Minimal example

```json
{
  "formatVersion": 1,
  "name": "My Repo",
  "apps": [
    {
      "id": "com.example.hello",
      "name": "Hello",
      "summary": "Demo app",
      "releases": [
        {
          "versionName": "1.0.0",
          "versionCode": 1,
          "url": "https://example.com/hello-1.0.0.apk"
        }
      ]
    }
  ]
}
```
