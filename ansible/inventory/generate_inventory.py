#!/usr/bin/env python3
"""Generate an Ansible inventory from Terraform's outputs.

This is the Terraform -> Ansible handoff the spec requires: no host IP is ever
typed by hand. For each workspace (dev, staging) it selects that workspace,
reads the `ansible_inventory` output object, and writes one INI file with a
[dev] and a [staging] group. Because both environments run simultaneously, both
groups are emitted so a single `ansible-playbook` run can target either or both.

The per-group login user, SSH key and app_port are NOT written here — they live
in group_vars/, which is the idiomatic place for them and keeps this script to
the one thing only Terraform knows: which hosts exist and at what IP.

Usage (run from the ansible/ directory):
    python3 inventory/generate_inventory.py            # dev + staging
    python3 inventory/generate_inventory.py --env dev  # just one

Requires the Terraform config one level up to have been applied in each
workspace you ask for.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

TF_DIR = Path(__file__).resolve().parents[2]  # base-terraform-starter/
OUT_FILE = Path(__file__).resolve().parent / "hosts.generated.ini"
ENVIRONMENTS = ["dev", "staging"]


def terraform(*args: str) -> str:
    result = subprocess.run(
        ["terraform", f"-chdir={TF_DIR}", *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"`terraform {' '.join(args)}` failed:\n{result.stderr.strip()}"
        )
    return result.stdout


def inventory_for(env: str):
    """Select the workspace and return its ansible_inventory output, or None."""
    terraform("workspace", "select", env)
    try:
        raw = terraform("output", "-json", "ansible_inventory")
    except RuntimeError:
        # Output not present -> environment not applied yet.
        return None
    data = json.loads(raw)
    return data if data.get("hosts") else None


def render(blocks: dict) -> str:
    lines = [
        "# GENERATED FILE — do not edit by hand.",
        "# Produced by inventory/generate_inventory.py from Terraform outputs.",
        "",
    ]
    for env, inv in blocks.items():
        lines.append(f"[{env}]")
        for idx, ip in enumerate(inv["hosts"]):
            lines.append(f"{env}-web-{idx} ansible_host={ip}")
        lines.append("")

    present = [e for e in blocks]
    if present:
        lines.append("[webservers:children]")
        lines.extend(present)
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env", choices=ENVIRONMENTS, help="Only this environment.")
    args = parser.parse_args()

    targets = [args.env] if args.env else ENVIRONMENTS
    blocks = {}
    for env in targets:
        inv = inventory_for(env)
        if inv is None:
            print(f"! {env}: not applied yet (no hosts) — skipping", file=sys.stderr)
            continue
        blocks[env] = inv
        print(f"+ {env}: {len(inv['hosts'])} host(s)", file=sys.stderr)

    if not blocks:
        print("No environments have hosts. Apply Terraform first.", file=sys.stderr)
        return 1

    OUT_FILE.write_text(render(blocks), encoding="utf-8")
    print(f"Wrote {OUT_FILE}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
