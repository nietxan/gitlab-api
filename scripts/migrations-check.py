#!/usr/bin/env python3
import re
from collections import defaultdict
from pathlib import Path


MIGRATION_RE = re.compile(r"^(\d+)_")


def iter_migration_dirs(root: Path):
    return root.glob("*/migrations")


def find_conflicts(root: Path):
    conflicts = {}
    for migrations_dir in iter_migration_dirs(root):
        if not migrations_dir.is_dir():
            continue
        migration_numbers = defaultdict(list)
        for path in migrations_dir.glob("*.py"):
            if path.name == "__init__.py":
                continue
            match = MIGRATION_RE.match(path.name)
            if not match:
                continue
            number = match.group(1)
            migration_numbers[number].append(path.name)
        duplicates = {
            number: files
            for number, files in migration_numbers.items()
            if len(files) > 1
        }
        if duplicates:
            conflicts[migrations_dir] = duplicates
    return conflicts


def main():
    repo_root = Path(__file__).resolve().parents[1]
    app_root = repo_root / "app"
    conflicts = find_conflicts(app_root)
    if not conflicts:
        print("No migration number conflicts found.")
        return 0

    print("Migration number conflicts detected:")
    for migrations_dir, duplicates in sorted(conflicts.items()):
        print(f"- {migrations_dir.relative_to(repo_root)}")
        for number, files in sorted(duplicates.items()):
            files_list = ", ".join(sorted(files))
            print(f"  - {number}: {files_list}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
