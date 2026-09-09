from __future__ import annotations

import re
from pathlib import Path

WORKFLOW_DIR = Path('.github/workflows')
MANUAL_TRIGGER = 'workflow_dispatch'

# Consumer mirror only. This repository may not mint Production exceptions.
# Add an entry only when an exact current âŒ– Vera / Production exception exists.
AUTHORIZED_AUTOMATIC_ENGINEERING_EXCEPTIONS: dict[tuple[str, str], str] = {}

ROUTINE_ENGINEERING_MARKERS = (
    'node --check',
    'node --test',
    'npm test',
    'npm run test',
    'npm run verify',
    'npm run build',
    'pytest',
    'vitest',
    'jest',
    'eslint',
    'tsc ',
    'swift build',
    'swift test',
    'xcodebuild',
    'cargo test',
    'go test',
    'dotnet test',
    'gradle test',
    'mvn test',
    'docker build',
)


def _top_level_on_block(text: str) -> str:
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line == 'on:'), None)
    if start is None:
        return ''

    block: list[str] = []
    for line in lines[start + 1:]:
        if line and not line.startswith((' ', '\t', '#')):
            break
        block.append(line)
    return '\n'.join(block)


def _triggers(text: str) -> set[str]:
    block = _top_level_on_block(text)
    return {
        match.group(1)
        for line in block.splitlines()
        if (match := re.match(r'^  ([A-Za-z_][A-Za-z0-9_-]*):(?:\s|$)', line))
    }


def _routine_engineering_markers(text: str) -> list[str]:
    lowered = text.lower()
    return [marker for marker in ROUTINE_ENGINEERING_MARKERS if marker in lowered]


def _manual_reason_is_required(text: str) -> bool:
    block = _top_level_on_block(text)
    return bool(
        re.search(
            r'^      qualification_reason:\s*$.*?^        required:\s*true\s*$',
            block,
            flags=re.MULTILINE | re.DOTALL,
        )
    )


def main() -> None:
    failures: list[str] = []
    workflows = sorted((*WORKFLOW_DIR.glob('*.yml'), *WORKFLOW_DIR.glob('*.yaml')))

    for path in workflows:
        text = path.read_text(encoding='utf-8').lstrip('\ufeff')
        triggers = _triggers(text)
        markers = _routine_engineering_markers(text)
        if not markers:
            continue

        automatic = sorted(trigger for trigger in triggers if trigger != MANUAL_TRIGGER)
        for trigger in automatic:
            exception_id = AUTHORIZED_AUTOMATIC_ENGINEERING_EXCEPTIONS.get((path.name, trigger))
            if not exception_id:
                failures.append(
                    f'{path}: unauthorized automatic {trigger!r} trigger executes routine '
                    f'engineering semantics ({", ".join(markers)})'
                )

        if MANUAL_TRIGGER in triggers and any(marker in text.lower() for marker in ('swift build', 'swift test', 'xcodebuild')):
            if not _manual_reason_is_required(text):
                failures.append(
                    f'{path}: remote native qualification must require qualification_reason'
                )

    if failures:
        raise SystemExit('workflow policy gate: FAIL\n- ' + '\n- '.join(failures))

    print(f'workflow policy gate: PASS ({len(workflows)} workflow file(s), '
          f'{len(AUTHORIZED_AUTOMATIC_ENGINEERING_EXCEPTIONS)} canonical automatic exception(s))')


if __name__ == '__main__':
    main()
