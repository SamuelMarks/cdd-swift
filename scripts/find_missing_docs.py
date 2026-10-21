"""Verify 100% documentation coverage across all Swift source files in Sources/.

Checks:
1. File-level header documentation at the top of every .swift file.
2. Every class, struct, actor, enum, protocol, typealias, associatedtype,
   func, init, subscript, var, let, and enum case declaration is preceded
   by a /// or /** ... */ documentation comment.
3. Every function/method/initializer with parameters documents its parameters
   via `- Parameter <name>:` or `- Parameters:`.
4. Rejects placeholder/corrupted docstrings (`/// Documentation for ...`,
   `/// Initializer.`, `/// The `x` property.`, corrupted typo comments,
   or duplicate consecutive comment lines).
"""

import os
import re
import sys
from typing import List, Tuple

DECL_PATTERN = re.compile(
    r"^\s*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|internal|fileprivate|private|open|final|static|class|override|mutating|nonmutating|convenience|required|indirect|lazy|weak|unowned)\s+)*"
    r"(?P<kind>class|struct|actor|enum|protocol|typealias|associatedtype|func|init|subscript|case)\b"
)

PROP_PATTERN = re.compile(
    r"^\s*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|internal|fileprivate|private|open|final|static|class|override|lazy|weak|unowned)\s+)*"
    r"(?P<kind>var|let)\s+(?P<name>[A-Za-z0-9_`]+)\s*:"
)

BANNED_DOC_PATTERNS = [
    re.compile(r"^///\s*Documentation for\b", re.IGNORECASE),
    re.compile(r"^///\s*Initializer\.\s*$"),
    re.compile(r"^///\s*The `[A-Za-z0-9_]+` property\.\s*$"),
    re.compile(r"Properation", re.IGNORECASE),
    re.compile(r"Operationtional", re.IGNORECASE),
    re.compile(r"^///\s*(?:Isrequired|Minlen|Maxlen|Typename)\.\s*$"),
]


def compute_brace_depths(lines: List[str]) -> List[int]:
    """Compute the brace nesting depth at the start of each line.

    Ignores braces inside string literals and comments.

    Args:
        lines: The source file lines.

    Returns:
        A list of integer brace depths corresponding to each line index.
    """
    depths: List[int] = []
    depth = 0
    in_block_comment = False
    in_multiline_string = False

    for line in lines:
        depths.append(depth)
        stripped = line.strip()
        if stripped.startswith("//"):
            continue

        i = 0
        n = len(line)
        while i < n:
            if in_block_comment:
                if line[i : i + 2] == "*/":
                    in_block_comment = False
                    i += 2
                    continue
                i += 1
                continue

            if in_multiline_string:
                if line[i : i + 3] == '"""':
                    in_multiline_string = False
                    i += 3
                    continue
                if ord(line[i]) == 92:
                    i += 2
                    continue
                i += 1
                continue

            if line[i : i + 2] == "//":
                break
            if line[i : i + 2] == "/*":
                in_block_comment = True
                i += 2
                continue
            if line[i : i + 3] == '"""':
                in_multiline_string = True
                i += 3
                continue
            if line[i] == '"':
                i += 1
                while i < n:
                    if ord(line[i]) == 92:
                        i += 2
                        continue
                    if line[i] == '"':
                        i += 1
                        break
                    i += 1
                continue

            if line[i] == "{":
                depth += 1
            elif line[i] == "}":
                depth = max(0, depth - 1)
            i += 1

    return depths


def collect_preceding_doc(lines: List[str], line_idx: int) -> List[str]:
    """Extract the contiguous doc comment lines immediately preceding `line_idx`.

    Skips blank lines, attributes (`@...`), and `#if`/`#elseif`/`#else` directives.

    Args:
        lines: All lines in the file.
        line_idx: The 0-based index of the declaration line.

    Returns:
        The list of doc comment lines in top-to-bottom order.
    """
    doc_lines: List[str] = []
    j = line_idx - 1
    in_block = False
    while j >= 0:
        prev = lines[j].strip()
        if in_block:
            doc_lines.append(prev)
            if prev.startswith("/**") or prev.startswith("/*"):
                in_block = False
            j -= 1
            continue
        if not prev and not doc_lines:
            j -= 1
            continue
        if (prev.startswith("@") or prev.startswith("#")) and not doc_lines:
            j -= 1
            continue
        if prev.endswith(")") and not doc_lines:
            # Check if this closes a multi-line @attribute(...) block
            k = j
            paren_depth = 0
            found_attr = False
            while k >= 0:
                line_k = lines[k].strip()
                paren_depth += line_k.count(")") - line_k.count("(")
                if paren_depth <= 0 and line_k.startswith("@"):
                    found_attr = True
                    break
                if line_k.startswith("///") or line_k.endswith("{") or line_k.endswith("}"):
                    break
                k -= 1
            if found_attr:
                j = k - 1
                continue
        if prev.startswith("///"):
            doc_lines.append(prev)
            j -= 1
            continue
        if prev.endswith("*/"):
            doc_lines.append(prev)
            if not (prev.startswith("/**") or prev.startswith("/*")):
                in_block = True
            j -= 1
            continue
        break
    doc_lines.reverse()
    return doc_lines


def extract_signature_parts(lines: List[str], line_idx: int) -> Tuple[str, str]:
    """Extract the parameter clause and trailing signature (throws / return type) of a declaration.

    Args:
        lines: All lines in the file.
        line_idx: The 0-based index where the declaration starts.

    Returns:
        A tuple `(inner_params, post_params_signature)` where `inner_params` is the
        content inside `(...)` and `post_params_signature` is the text between `)` and `{` (or end of declaration).
    """
    sig = ""
    for j in range(line_idx, min(len(lines), line_idx + 25)):
        sig += lines[j]
        if "{" in lines[j] or (")" in sig and "(" in sig):
            open_idx = sig.find("(")
            if open_idx != -1:
                depth = 0
                for k in range(open_idx, len(sig)):
                    if sig[k] == "(":
                        depth += 1
                    elif sig[k] == ")":
                        depth -= 1
                        if depth == 0:
                            inner = sig[open_idx + 1 : k].strip()
                            rest = sig[k + 1 :]
                            if "{" in rest:
                                rest = rest[: rest.find("{")]
                            else:
                                rest = rest.splitlines()[0] if rest else ""
                            return inner, rest.strip()
    return "", ""


def has_signature_parameters(lines: List[str], line_idx: int) -> bool:
    """Determine whether a `func`, `init`, or `subscript` signature has one or more parameters.

    Args:
        lines: All lines in the file.
        line_idx: The 0-based index where the declaration starts.

    Returns:
        `True` if the parameter list is non-empty, `False` if `()`.
    """
    inner, _ = extract_signature_parts(lines, line_idx)
    return len(inner) > 0


def signature_requires_returns_and_throws(
    lines: List[str], line_idx: int, kind: str
) -> Tuple[bool, bool]:
    """Determine whether a declaration in `Sources/` requires `- Returns:` and/or `- Throws:` tags.

    Args:
        lines: All lines in the file.
        line_idx: The 0-based index where the declaration starts.
        kind: The declaration kind (`func`, `init`, `subscript`).

    Returns:
        A tuple `(needs_returns, needs_throws)`.
    """
    if kind not in ("func", "init", "subscript"):
        return False, False
    _, post_sig = extract_signature_parts(lines, line_idx)
    needs_returns = (
        kind in ("func", "subscript")
        and "->" in post_sig
        and "-> Void" not in post_sig
        and "-> ()" not in post_sig
    )
    needs_throws = (
        bool(re.search(r"\bthrows\b", post_sig)) and "rethrows" not in post_sig
    )
    return needs_returns, needs_throws


def audit_file(filepath: str) -> Tuple[int, int, List[str]]:
    """Audit a single Swift file for documentation coverage and quality.

    Args:
        filepath: Path to the Swift file.

    Returns:
        A tuple of `(total_items, documented_items, issues)`.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    issues: List[str] = []
    total_items = 0
    documented_items = 0

    # 1. Check file header doc comment
    total_items += 1
    has_file_header = False
    for line in lines:
        s = line.strip()
        if (
            not s
            or s.startswith("#if")
            or s.startswith("#elseif")
            or s.startswith("#else")
        ):
            continue
        if s.startswith("///") or s.startswith("/**"):
            has_file_header = True
        break
    if has_file_header:
        documented_items += 1
    else:
        issues.append(f"{filepath}:1:Missing file-level header documentation comment")

    # 2. Check for banned/corrupted docstrings & duplicate consecutive comments
    in_multiline_str = False
    for i, line in enumerate(lines):
        triple_count = line.count('"""')
        if in_multiline_str:
            if triple_count % 2 == 1:
                in_multiline_str = False
            continue
        if triple_count % 2 == 1:
            in_multiline_str = True
            continue

        stripped = line.strip()
        for pat in BANNED_DOC_PATTERNS:
            if pat.search(stripped):
                issues.append(
                    f"{filepath}:{i + 1}:Banned/placeholder or corrupted docstring: {stripped}"
                )
        if i > 0 and stripped.startswith("//") and stripped not in ("///", "//"):
            prev_stripped = lines[i - 1].strip()
            if stripped == prev_stripped:
                issues.append(
                    f"{filepath}:{i + 1}:Duplicate consecutive comment line: {stripped}"
                )

    depths = compute_brace_depths(lines)
    # Track which brace depths correspond to type declarations (class, struct, enum, protocol, actor, extension)
    type_brace_depths = {0}
    type_header_pattern = re.compile(
        r"^\s*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s+)*"
        r"(?:(?:public|internal|fileprivate|private|open|final|indirect)\s+)*"
        r"(?:class|struct|actor|enum|protocol|extension)\b"
    )

    in_multiline_string = False
    for i, line in enumerate(lines):
        # Track multiline string state so we don't match code templates inside raw strings
        triple_count = line.count('"""')
        if in_multiline_string:
            if triple_count % 2 == 1:
                in_multiline_string = False
            continue
        if triple_count % 2 == 1:
            in_multiline_string = True
            continue

        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue

        current_depth = depths[i]
        # Clean out deeper depths when braces close
        type_brace_depths = {d for d in type_brace_depths if d <= current_depth}

        if type_header_pattern.search(line) and "{" in line:
            type_brace_depths.add(current_depth + 1)

        if current_depth not in type_brace_depths:
            continue

        decl_match = DECL_PATTERN.search(line)
        prop_match = PROP_PATTERN.search(line) if not decl_match else None

        if decl_match:
            kind = decl_match.group("kind")
            # Ignore `case` inside switch statements (switch cases end with `:`)
            if kind == "case" and stripped.endswith(":"):
                continue
            total_items += 1
            doc_lines = collect_preceding_doc(lines, i)
            if not doc_lines:
                issues.append(f"{filepath}:{i + 1}:Undocumented {kind}: {stripped}")
            else:
                has_banned = any(
                    pat.search(dl) for dl in doc_lines for pat in BANNED_DOC_PATTERNS
                )
                doc_text = "\n".join(doc_lines)
                missing_param_doc = False
                if kind in ("func", "init", "subscript") and has_signature_parameters(
                    lines, i
                ):
                    if (
                        "- Parameter" not in doc_text
                        and "- Parameters:" not in doc_text
                        and "- parameter" not in doc_text
                        and "- parameters:" not in doc_text
                    ):
                        missing_param_doc = True
                        issues.append(
                            f"{filepath}:{i + 1}:Missing `- Parameter` documentation on {kind}: {stripped}"
                        )
                missing_ret_or_throws = False
                if filepath.startswith("Sources") or "/Sources/" in filepath:
                    needs_returns, needs_throws = signature_requires_returns_and_throws(
                        lines, i, kind
                    )
                    if (
                        needs_returns
                        and "- Returns:" not in doc_text
                        and "- returns:" not in doc_text
                    ):
                        missing_ret_or_throws = True
                        issues.append(
                            f"{filepath}:{i + 1}:Missing `- Returns:` documentation on {kind}: {stripped}"
                        )
                    if (
                        needs_throws
                        and kind == "func"
                        and "- Throws:" not in doc_text
                        and "- throws:" not in doc_text
                    ):
                        missing_ret_or_throws = True
                        issues.append(
                            f"{filepath}:{i + 1}:Missing `- Throws:` documentation on {kind}: {stripped}"
                        )
                if not has_banned and not missing_param_doc and not missing_ret_or_throws:
                    documented_items += 1
        elif prop_match:
            kind = prop_match.group("kind")
            total_items += 1
            doc_lines = collect_preceding_doc(lines, i)
            if not doc_lines:
                issues.append(
                    f"{filepath}:{i + 1}:Undocumented property ({kind}): {stripped}"
                )
            else:
                has_banned = any(
                    pat.search(dl) for dl in doc_lines for pat in BANNED_DOC_PATTERNS
                )
                if not has_banned:
                    documented_items += 1

    return total_items, documented_items, issues


def scan_sources(root_dir: str = "Sources") -> Tuple[int, int, List[str]]:
    """Scan all `.swift` files under `root_dir` (and `Tests` when scanning default `Sources`) for documentation coverage.

    Args:
        root_dir: The root source directory to scan.

    Returns:
        A tuple of `(total_items, documented_items, all_issues)`.
    """
    total = 0
    documented = 0
    all_issues: List[str] = []

    dirs_to_scan = [root_dir]
    if root_dir == "Sources" and os.path.isdir("Tests"):
        dirs_to_scan.append("Tests")

    for scan_dir in dirs_to_scan:
        for root, _, files in sorted(os.walk(scan_dir)):
            for file in sorted(files):
                if not file.endswith(".swift"):
                    continue
                filepath = os.path.join(root, file)
                t, d, issues = audit_file(filepath)
                total += t
                documented += d
                all_issues.extend(issues)

    return total, documented, all_issues


def main() -> int:
    """CLI entrypoint for `find_missing_docs.py`."""
    _, _, issues = scan_sources("Sources")
    for issue in issues:
        print(issue)
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
