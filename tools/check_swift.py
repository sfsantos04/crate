#!/usr/bin/env python3
"""Balanço de delimitadores em Swift, entendendo comentários, strings e
interpolação \\( ... ) dentro de strings (o scanner volta ao modo string
quando a interpolação fecha)."""
import glob
import sys

OPEN = {"{": "}", "(": ")", "[": "]"}
CLOSE = {v: k for k, v in OPEN.items()}


def scan(src, path):
    stack = []          # cada item: [abertura, veio_de_string]
    i = 0
    n = len(src)
    in_line_comment = False
    block_depth = 0
    in_string = False

    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        if block_depth:
            if ch == "*" and nxt == "/":
                block_depth -= 1
                i += 2
                continue
            if ch == "/" and nxt == "*":
                block_depth += 1
                i += 2
                continue
            i += 1
            continue

        if in_string:
            if ch == "\\":
                if nxt == "(":
                    stack.append(["(", True])
                    in_string = False
                    i += 2
                    continue
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_depth = 1
            i += 2
            continue
        if ch == '"':
            in_string = True
            i += 1
            continue
        if ch in OPEN:
            stack.append([ch, False])
        elif ch in CLOSE:
            if not stack:
                return f"{path}: '{ch}' sem abertura na posição {i}"
            opener, from_string = stack.pop()
            if OPEN[opener] != ch:
                return f"{path}: esperava '{OPEN[opener]}', achei '{ch}' na posição {i}"
            if from_string:
                in_string = True  # volta para dentro da string interpolada
        i += 1

    if stack:
        return f"{path}: sobrou {len(stack)} sem fechar: {''.join(e[0] for e in stack)}"
    if in_string:
        return f"{path}: string não terminada"
    return None


def main():
    problems = []
    for path in sorted(glob.glob("Sources/**/*.swift", recursive=True)):
        problem = scan(open(path, encoding="utf-8").read(), path)
        print(("FALHA  " if problem else "ok     ") + path)
        if problem:
            problems.append(problem)
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
