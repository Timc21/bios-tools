#!/usr/bin/env python3
# desc:  Extract and pretty-print JSON from raw text files
# repo:  https://github.com/Timc21/bios_tools
# usage: python json_trans.py <input_file> [output_file]
import json
import sys
import os
import re

def extract_json(text):
    # Find JSON block starting with { and ending with }
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError("No JSON object found in the file.")
    return match.group(0)

def pretty_print_json(input_file, output_file=None):
    with open(input_file, "r", encoding="utf-8", errors="ignore") as f:
        raw_text = f.read()

    try:
        clean_json_text = extract_json(raw_text)
        data = json.loads(clean_json_text)
    except Exception as e:
        print("JSON parsing error:", e)
        return

    # Output filename
    if not output_file:
        base, ext = os.path.splitext(input_file)
        output_file = f"{base}_pretty.json"

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    print(f"✓ Pretty JSON saved to: {output_file}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 json_trans.py <input_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    pretty_print_json(input_file, output_file)
