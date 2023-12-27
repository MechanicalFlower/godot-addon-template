# Usage

To generate a `reference.json`, run:
```
godot --editor --headless --quit --script addons/godot-autogen-docs/reference_collector_cli.gd
```

And to turn this JSON file into markdown, run:
```
godot --headless --quit --script addons/godot-autogen-docs/markdown.gd
```
