#!/usr/bin/env python3
"""Declared human writing requests. Parsing never authorizes a write."""
import argparse
import json
import re
from pathlib import Path


def response_section(body):
    """Read the top-level declaration, excluding fences and quoted context."""
    found = False
    collecting = False
    lines = []
    fence = None
    for line in body.replace('\r\n', '\n').splitlines():
        delimiter = re.match(r'^ {0,3}(`{3,}|~{3,})', line)
        if delimiter:
            if fence is None:
                fence = delimiter[1][0]
            elif fence == delimiter[1][0]:
                fence = None
            if collecting:
                lines.append(line)
            continue
        if fence:
            if collecting:
                lines.append(line)
            continue
        heading = re.match(r'^(#{1,3})[ \t]+(.+?)[ \t]*$', line)
        if heading:
            if heading[2] == 'Context':
                break
            if heading[1] == '###' and heading[2] == 'Human response':
                if found:
                    raise ValueError('duplicate Human response section')
                found = True
                collecting = True
                continue
            if found:
                collecting = False
        if collecting:
            lines.append(line)
    text = '\n'.join(lines).strip()
    return text if found and text not in ('', '_No response_') else None


def parse_response(body):
    raw = response_section(body)
    if raw is None:
        return None
    values = {}
    for line in raw.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([A-Za-z ]+):[ \t]*(\S(?:.*\S)?)[ \t]*', line)
        if not match or match[1] in values:
            raise ValueError('Human response needs unique named fields')
        values[match[1]] = match[2]
    required = {'Type', 'Target', 'Field', 'Max characters', 'Completion'}
    if not required.issubset(values) or set(values) - required - {'Repair marker'}:
        raise ValueError('Human response has missing or unknown fields')
    if values['Type'] != 'write-outcome' or values['Field'] != 'Outcome':
        raise ValueError('Human response supports only write-outcome / Outcome')
    if not re.fullmatch(r'[\w.-]+/[\w.-]+#[1-9][0-9]*', values['Target'], flags=re.ASCII):
        raise ValueError('Human response Target must be owner/repo#number')
    if int(values['Target'].split('#')[1]) > 9007199254740991:
        raise ValueError('Human response Target number is not safe')
    if values['Max characters'] != '220' or values['Completion'] != 'saved-outcome':
        raise ValueError('Human response requires 220 characters and saved-outcome completion')
    if 'Repair marker' in values and values['Repair marker'] != 'yes':
        raise ValueError('Repair marker must be yes or omitted')
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('body_file')
    parser.add_argument('--present', action='store_true', help='identify human ownership, including invalid declarations')
    parser.add_argument('--ready-for-review', action='store_true')
    args = parser.parse_args()
    body = Path(args.body_file).read_text()
    try:
        raw = response_section(body)
        if args.present:
            return 0 if raw is not None else 1
        response = parse_response(body)
        if args.ready_for_review and response is not None:
            raise ValueError('a writing request is not a delivered result review')
    except ValueError as error:
        if args.present:
            return 0
        print('not compliant: ' + str(error))
        return 1
    print('write-outcome' if response else 'none')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
