#!/usr/bin/env python3
"""Crude Dart balance checker: brackets outside strings/comments.

Handles: // and /* */ comments, single/double quoted strings (incl. triple),
raw strings (r'..'), and $identifier / ${...} interpolation.
It only reports bracket balance + line numbers where the depth misbehaves.
"""
from __future__ import annotations

import sys
from pathlib import Path

OPEN = {'(': ')', '[': ']', '{': '}'}
CLOSE = {v: k for k, v in OPEN.items()}


def check(text: str) -> tuple[int, list[str]]:
    problems: list[str] = []
    stack: list[tuple[str, int]] = []
    i = 0
    line = 1
    n = len(text)

    def push(ch: str) -> None:
        stack.append((ch, line))

    def pop(ch: str) -> None:
        if not stack:
            problems.append(f'line {line}: unexpected closing {ch!r}')
            return
        top, top_line = stack.pop()
        if OPEN[top] != ch:
            problems.append(f'line {line}: {ch!r} closes {top!r} opened on line {top_line}')

    while i < n:
        ch = text[i]

        if ch == '\n':
            line += 1
            i += 1
            continue

        # comments
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if ch == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                if text[i] == '\n':
                    line += 1
                i += 1
            i += 2
            continue

        # strings
        raw = False
        start = i
        if ch in 'rR' and i + 1 < n and text[i + 1] in '\'"':
            raw = True
            i += 1
            ch = text[i]
        if ch in '\'"':
            quote = ch
            triple = text[i:i + 3] == quote * 3
            delimiter = quote * (3 if triple else 1)
            i += len(delimiter)
            while i < n:
                if not raw and text[i] == '\\':
                    i += 2
                    continue
                if text[i] == '\n':
                    line += 1
                    if not triple:
                        problems.append(f'line {line}: unterminated string starting at {start}')
                        break
                if text[i:i + len(delimiter)] == delimiter:
                    i += len(delimiter)
                    break
                if not raw and text[i] == '$' and i + 1 < n:
                    nxt = text[i + 1]
                    if nxt == '{':
                        # interpolation expression: count braces
                        depth = 0
                        i += 1
                        while i < n:
                            if text[i] == '{':
                                depth += 1
                            elif text[i] == '}':
                                depth -= 1
                                if depth == 0:
                                    i += 1
                                    break
                            elif text[i] == '\n':
                                line += 1
                            i += 1
                        continue
                    if nxt.isalpha() or nxt == '_':
                        i += 1
                        while i < n and (text[i].isalnum() or text[i] == '_'):
                            i += 1
                        continue
                i += 1
            continue

        if ch in OPEN:
            push(ch)
        elif ch in CLOSE:
            pop(ch)
        i += 1

    if stack:
        problems.append(f'unclosed: ' + ', '.join(f'{c!r} from line {l}' for c, l in stack))
    return len(stack), problems


if __name__ == '__main__':
    failed = False
    for arg in sys.argv[1:]:
        path = Path(arg)
        _, problems = check(path.read_text())
        if problems:
            failed = True
            print(f'{path}:')
            for problem in problems:
                print('   ', problem)
        else:
            print(f'{path}: ok')
    sys.exit(1 if failed else 0)
