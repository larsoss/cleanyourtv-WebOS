# Lars' CleanYourTV add-ons

An add-on repository for [CleanYourTV](https://github.com/lasharor/cleanyourtv-WebOS) (the format of its add-on repositories, `docs/development/addon-repos.md`).

| Add-on | What it does |
|---|---|
| `seasons` | Photos for the couch scenes that follow the calendar: Christmas, New Year, then the season (turned around south of the equator; tulips only in NL and BE). Needs a service with `scenes` (pull request #166). |

## On a TV

```sh
node /media/developer/cleanyourtv/cytv-addons.js shortcut   # once
cytv-addons repo-add larsoss/cleanyourtv-WebOS@tv-addons
cytv-addons install seasons larsoss-cleanyourtv-webos
```

After a change to an add-on: raise its `version`, run `node make-index.js`, commit `index.json` with it.
