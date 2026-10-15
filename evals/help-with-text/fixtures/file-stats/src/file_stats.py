import argparse
import sys


def count(text, args):
    if args.words:
        return f"{len(text.split())}"
    if args.lines:
        return f"{len(text.splitlines())}"
    return f"{len(text.splitlines())} {len(text.split())} {len(text)}"


def main():
    parser = argparse.ArgumentParser(description="Count lines, words and characters.")
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--words", action="store_true")
    parser.add_argument("--lines", action="store_true")
    parser.add_argument("--verbose", action="store_true", help="print each file's path before its counts")
    args = parser.parse_args()

    failed = False
    for path in args.paths:
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError:
            failed = True
            continue
        if args.verbose:
            print(path)
        print(count(text, args))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
