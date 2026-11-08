"""Writes Luau that changes a Studio script from one version of a file to another, by line
numbers, so only the new lines travel. The Luau first checks that the script holds the old
version, applies the changes from the bottom up, and returns the new text's checksum.

Studio's assistant blocks HTTP to 127.0.0.1 and GitHub from execute_luau, so scripts can't
be fetched from a local server any more. Instead, run the Luau this writes with
execute_luau in Edit mode. The old file is usually `git show <commit>:<path>` for the
version Studio holds; compare checksums first. The checksum is djb2 over the UTF-8 bytes
(h = h * 33 + byte, mod 2^32), the same as the Luau one.

Usage: python3 tools/studio_patch.py <old file> <new file> <script path in game> <out .luau>
For example: ServerScriptService.BakerySystem
"""
import difflib
import sys

old_path, new_path, script_path, out_path = sys.argv[1:5]
old_text = open(old_path).read()
new_text = open(new_path).read()
old_lines = old_text.split("\n")
new_lines = new_text.split("\n")


def checksum(text):
    value = 5381
    for byte in text.encode("utf-8"):
        value = (value * 33 + byte) % 4294967296
    return value


def long_string(text):
    level = 0
    while "]" + "=" * level + "]" in text or text.endswith("]" + "=" * level):
        level += 1
    eq = "=" * level
    # A newline straight after the opening bracket is dropped, so text starting with one
    # survives.
    return "[" + eq + "[\n" + text + "]" + eq + "]"


ops = []
matcher = difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False)
for tag, i1, i2, j1, j2 in matcher.get_opcodes():
    if tag != "equal":
        ops.append((i1, i2, new_lines[j1:j2]))

# Check the patch rebuilds the new text, applying from the bottom up like the Luau does.
lines = list(old_lines)
for i1, i2, insert in reversed(ops):
    lines[i1:i2] = insert
assert "\n".join(lines) == new_text

out = [
    "local function checksum(s)",
    "\tlocal h = 5381",
    "\tfor i = 1, #s do",
    "\t\th = (h * 33 + string.byte(s, i)) % 4294967296",
    "\tend",
    "\treturn h",
    "end",
    f"local script = game:GetService({script_path.split('.')[0]!r})",
]
for name in script_path.split(".")[1:]:
    out.append(f"script = script:FindFirstChild({name!r})")
out += [
    f"if not script or checksum(script.Source) ~= {checksum(old_text)} then",
    "\treturn 'Not patched: the script is not the expected old version'",
    "end",
    "local lines = string.split(script.Source, '\\n')",
    "local function splice(first, last, text)",
    "\tfor _ = first, last do",
    "\t\ttable.remove(lines, first)",
    "\tend",
    "\tif text then",
    "\t\tfor index, line in string.split(text, '\\n') do",
    "\t\t\ttable.insert(lines, first + index - 1, line)",
    "\t\tend",
    "\tend",
    "end",
]
for i1, i2, insert in reversed(ops):
    text = long_string("\n".join(insert)) if insert else "nil"
    out.append(f"splice({i1 + 1}, {i2}, {text})")
out += [
    "script.Source = table.concat(lines, '\\n')",
    f"return ('patched %d lines, checksum %d (expected {checksum(new_text)})'):format(#lines, checksum(script.Source))",
]
open(out_path, "w").write("\n".join(out) + "\n")
print(f"{len(ops)} changes, {sum(len(chr(10).join(o[2])) for o in ops)} characters of new lines, Luau {len(chr(10).join(out))} characters")
