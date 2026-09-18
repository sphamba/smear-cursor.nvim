#!/usr/bin/env python3
"""Generate the `SmearCursor.Config` LuaCATS class for the LSP.

The fields come from the `M.<name> = <default>` lines in
`lua/smear_cursor/config.lua`. The class block sits between two marker
comments in the same file. Tools that run this script:

- the local pre-commit hook in `.pre-commit-config.yaml`
- the `luadoc` and `luadoc-check` targets in the `Makefile`

Usage:

    python3 scripts/generate_config_luadoc.py          Update the block in place
    python3 scripts/generate_config_luadoc.py --check  Exit 1 when the block is stale
"""

import argparse
import re
import sys
from pathlib import Path

# Path of this script, anchored to the location of the script on disk.
REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_FILE = REPO_ROOT / "lua/smear_cursor/config.lua"
SCRIPT_PATH = "scripts/generate_config_luadoc.py"
CLASS_NAME = "SmearCursor.Config"
BEGIN_MARKER = "-- BEGIN generated luadoc, do not edit (run scripts/generate_config_luadoc.py to update)"
END_MARKER = "-- END generated luadoc"

FIELD_RE = re.compile(r"^M\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*(?:--\s*.*)?$")

# Field types that cannot be inferred from the default value.
FIELD_TYPE_OVERRIDES = {
    # The default is an empty table; the plugin stores a list of filetypes.
    "filetypes_disabled": "string[]",
    # The default is `nil`; the value is a duration in milliseconds.
    "delay_disable": "integer",
    # Note: do not add float fields here. Write the default with a `.0`
    # suffix in `config.lua`; the generator then types it as `number`.
}

# Fields without a default in `config.lua`. `setup()` accepts these options.
EXTRA_FIELDS = {
    # The default `enabled = true` is applied in `lua/smear_cursor/init.lua`.
    "enabled": "boolean",
}


def infer_type(name: str, value: str) -> str:
    """Return the LuaCATS type for one default value."""
    if name in FIELD_TYPE_OVERRIDES:
        return FIELD_TYPE_OVERRIDES[name]
    value = value.strip()
    if value in ("true", "false"):
        return "boolean"
    if value == "nil":
        return "nil"
    if re.fullmatch(r"-?\d+", value):
        return "integer"
    if re.fullmatch(r"-?\d*\.\d+", value):
        return "number"
    if value.startswith("vim.log.levels."):
        return "vim.log.levels"
    # Computed numeric expression, e.g. `(1 / 3) / 1.5` or `math.pi / 16`.
    if re.fullmatch(r"[\w\s*/+%.()-]*", value) and re.search(r"\d|math\.|vim\.", value):
        return "number"
    sys.exit(
        f"Cannot infer the type of `{name}` from value `{value}`.\n"
        f"Add the type to `FIELD_TYPE_OVERRIDES` in {SCRIPT_PATH}."
    )


def parse_fields() -> list:
    """Collect the settable options, in the order of `config.lua`."""
    fields = [(name, lua_type) for name, lua_type in EXTRA_FIELDS.items()]
    for line in CONFIG_FILE.read_text().splitlines():
        match = FIELD_RE.match(line)
        if not match:
            continue
        name, value = match.group(1), match.group(2)
        fields.append((name, infer_type(name, value)))
    return fields


def build_block(fields: list) -> str:
    lines = [f"--- @class {CLASS_NAME}"]
    lines += [f"--- @field {name}? {lua_type}" for name, lua_type in fields]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write; exit 1 when the block is not up to date",
    )
    args = parser.parse_args()

    fields = parse_fields()
    block = build_block(fields)
    text = CONFIG_FILE.read_text()

    begin = text.find(BEGIN_MARKER)
    end = text.find(END_MARKER)
    if begin == -1 or end == -1 or begin > end:
        sys.exit(
            f"`{CONFIG_FILE}` does not contain the one-time markers:\n"
            f"  {BEGIN_MARKER}\n"
            f"  {END_MARKER}\n"
            f"Wrap the generated luadoc block with these markers once."
        )

    updated = f"{text[:begin + len(BEGIN_MARKER)]}\n{block}\n{text[end:]}"

    if updated == text:
        sys.exit(0)  # Already current
    if args.check:
        print(f"{CONFIG_FILE} is not up to date. Run `python3 {SCRIPT_PATH}` to update it.")
        sys.exit(1)
    CONFIG_FILE.write_text(updated)
    print(f"Updated {CONFIG_FILE}.")


if __name__ == "__main__":
    main()
