"""IAM 정책의 동작(Action)을 AWS 공식 Service Reference(기계 판독용 JSON)와 대조한다.

사용:  python verify/check_actions.py <.tf 파일들> [--offline] [--out=파일명.md]
출력:  results/verify_actions.md (표) — ERROR 가 있으면 종료 코드 1

규칙
  E1 존재하지 않는 동작              (오타·지어낸 이름 — 정책이 아무 효과 없음)
  E2 대상 지정을 지원하지 않는데 ARN 지정  (Resource 가 '*' 가 아니면 권한이 실제로 허용되지 않음)
  W1 Resource '*' 인데 대상 지정 가능    (더 좁힐 수 있음)
  W2 권한 관리(IsPermissionManagement) 동작  (권한 상승 경로 — 어느 역할에 있는지 사람이 확인)

한계: .tf 를 가볍게 파싱한다(정규식 + 괄호 짝). AWS 관리 정책(AmazonEC2FullAccess 등)의 내용과
      Condition 은 검사하지 않는다. 실제 계정의 정책 검증은 IAM Access Analyzer validate-policy 로 한다.
"""
import fnmatch, json, pathlib, re, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "results" / "service_reference"
BASE = "https://servicereference.us-east-1.amazonaws.com/v1/{s}/{s}.json"
ACTION_RE = re.compile(r'"([a-z0-9-]+:[A-Za-z0-9*]+)"')


def service_ref(svc, offline):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / f"{svc}.json"
    if not f.exists():
        if offline:
            sys.exit(f"캐시 없음: {f}")
        with urllib.request.urlopen(BASE.format(s=svc), timeout=30) as r:
            f.write_bytes(r.read())
    return json.loads(f.read_text(encoding="utf-8"))


def block_at(text, pos):
    """pos 를 감싸는 가장 안쪽 { ... } 블록"""
    depth, start = 0, pos
    while start > 0:
        c = text[start]
        if c == "}":
            depth += 1
        elif c == "{":
            if depth == 0:
                break
            depth -= 1
        start -= 1
    depth, end = 0, start
    while end < len(text):
        c = text[end]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        end += 1
    return text[start:end + 1]


def value_of(block, key):
    """block 안의 `key = ...` 값 (한 줄 또는 [ ... ] 여러 줄)"""
    m = re.search(rf'\b{key}\s*=\s*', block)
    if not m:
        return ""
    rest = block[m.end():]
    if rest.startswith("["):
        return rest[: rest.index("]") + 1]
    if rest.startswith('"'):
        return re.match(r'"[^"]*"', rest).group(0)
    return re.match(r"[^\s,}]+", rest).group(0)


def statements(path):
    text = path.read_text(encoding="utf-8")
    seen = set()
    for m in re.finditer(r'\bAction\s*=', text):
        blk = block_at(text, m.start())
        if blk in seen or "Principal" in blk:   # 신뢰 정책(누가 역할을 쓰나)은 권한 정책이 아니므로 제외
            continue
        seen.add(blk)
        sid = re.search(r'Sid\s*=\s*"([^"]+)"', blk)
        line = text[: m.start()].count("\n") + 1
        yield {
            "file": path.name, "line": line, "sid": sid.group(1) if sid else "-",
            "actions": ACTION_RE.findall(value_of(blk, "Action")),
            "resource": value_of(blk, "Resource").strip(),
        }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    offline = "--offline" in sys.argv
    rows, errors = [], 0
    refs = {}
    for p in args:
        for st in statements(pathlib.Path(p)):
            star = st["resource"].strip('"') == "*"
            for act in st["actions"]:
                svc, name = act.split(":", 1)
                ref = refs.setdefault(svc, service_ref(svc, offline))
                matched = [a for a in ref["Actions"] if fnmatch.fnmatchcase(a["Name"], name)]
                findings = []
                if not matched:
                    findings.append("E1 존재하지 않는 동작")
                else:
                    scoped = any(a.get("Resources") for a in matched)
                    if not star and not scoped and name != "*" and "*" not in name:
                        findings.append("E2 대상 지정 불가인데 ARN 지정")
                    if star and scoped and "*" not in name:
                        findings.append("W1 '*' 대신 좁힐 수 있음: " + ", ".join(sorted({r['Name'] for a in matched for r in a.get('Resources', [])})))
                    if any(a.get("Annotations", {}).get("Properties", {}).get("IsPermissionManagement") for a in matched):
                        findings.append("W2 권한 관리 동작")
                errors += any(f.startswith("E") for f in findings)
                rows.append((st["file"], st["line"], st["sid"], act, len(matched), "; ".join(findings) or "OK"))
    name = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--out=")), "verify_actions.md")
    out = ROOT / "results" / name
    with out.open("w", encoding="utf-8") as f:
        f.write("# 동작(Action) 검증 결과 — AWS Service Reference 대조\n\n")
        f.write("서비스 데이터 버전(modified, epoch): " + ", ".join(f"{s}={r.get('Version', '?')}" for s, r in sorted(refs.items())) + "\n\n")
        f.write("| 파일 | 행 | Sid | 동작 | 일치 수 | 판정 |\n|---|---|---|---|---|---|\n")
        for r in rows:
            f.write("| " + " | ".join(map(str, r)) + " |\n")
        f.write(f"\nERROR {errors}건, 검사한 동작 {len(rows)}개\n")
    for r in rows:
        if r[5] != "OK":
            print(f"{r[0]}:{r[1]} [{r[2]}] {r[3]} -> {r[5]}")
    print(f"ERROR {errors} / 동작 {len(rows)} -> {out.relative_to(ROOT)}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
