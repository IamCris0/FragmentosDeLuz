"""Run isolated demo regressions; require a fresh report and an error-free Godot run."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "save": (["--script", "res://tools/qa_save_store.gd"], ["--qa"], "adventure/save_report.json"),
    "regressions": (["--script", "res://tools/qa_demo_regressions.gd"], ["--qa-regressions"], "demo/regressions_report.json"),
    "route": ([], ["--qa"], "adventure/qa_report.json"),
    "combat": ([], ["--qa", "--qa-combat"], "adventure/combat_report.json"),
    "guardian": ([], ["--qa", "--qa-guardian"], "adventure/guardian_report.json"),
    "gamepad": ([], ["--qa", "--qa-gamepad"], "adventure/gamepad_report.json"),
    "memories": ([], ["--qa", "--qa-memories"], "adventure/memories_report.json"),
    "grutas": (["res://scenes/levels/grutas.tscn"], ["--qa"], "levels/grutas_report.json"),
    "cefiro": (["res://scenes/levels/cefiro.tscn"], ["--qa"], "levels/cefiro_report.json"),
    "observatorio": (["res://scenes/levels/observatorio.tscn"], ["--qa"], "levels/observatorio_report.json"),
    "skills": (["res://scenes/levels/grutas.tscn"], ["--qa", "--qa-skills"], "levels/skills_report.json"),
    "avatar": ([], ["--qa", "--qa-avatar"], "adventure/avatar_report.json"),
    "menu": ([], ["--qa-menu"], "adventure/menu_report.json"),
    "map": (["res://scenes/archipelago_map.tscn"], ["--qa", "--qa-map"], "levels/map_report.json"),
    "prologue": ([], ["--qa-prologue"], "adventure/prologue_report.json"),
    "art": (["res://scenes/archipelago_map.tscn"], ["--qa-art"], "levels/art_report.json"),
}
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|QA_FAILED:|Failed loading resource|ERROR:")
# Track teardown diagnostics separately, while still failing on every ERROR.
SHUTDOWN = re.compile(r"^ERROR: (?:\d+ resources still in use|\d+ RID allocations)", re.MULTILINE)


def run_process(command, log, env, timeout):
    try:
        with log.open("w", encoding="utf-8") as stream:
            completed = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                                       stderr=subprocess.STDOUT, timeout=timeout, check=False)
        return completed.returncode
    except subprocess.TimeoutExpired:
        with log.open("a", encoding="utf-8") as stream:
            stream.write("\nVALIDATION_TIMEOUT\n")
        return -1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_EXE") or shutil.which("godot"))
    parser.add_argument("--visual", action="store_true", help="Render captures; opens temporary test windows")
    parser.add_argument("--verbose", action="store_true", help="Include Godot resource diagnostics in each log")
    parser.add_argument("--cases", nargs="+", choices=CASES)
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=240, help="Maximum wall-clock seconds per case")
    args = parser.parse_args()
    if not args.godot or not Path(args.godot).is_file():
        parser.error("Specify --godot with the Godot executable, or set GODOT_EXE.")
    if args.repeat < 1 or args.timeout < 1:
        parser.error("repeat and timeout must be positive")
    names = args.cases or [name for name in CASES if args.visual or name not in {"avatar", "menu", "map", "art", "prologue"}]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")
    output = ROOT / "artifacts" / "validation" / stamp
    output.mkdir(parents=True)
    env = dict(os.environ, FDL_QA_OUTPUT=str(output))
    common = [str(Path(args.godot).resolve()), "--path", str(ROOT / "godot")]
    if args.verbose:
        common += ["--verbose"]
    import_log = output / "import.log"
    code = run_process(common + ["--headless", "--editor", "--import", "--quit"], import_log, env, args.timeout)
    import_text = import_log.read_text(encoding="utf-8", errors="replace")
    if code or ERRORS.search(import_text):
        print(f"Import failed. See {import_log}")
        return 1
    results = []
    for repetition in range(args.repeat):
        for name in names:
            case_dir = output / f"{name}_{repetition + 1}"
            case_dir.mkdir()
            env["FDL_QA_OUTPUT"] = str(case_dir)
            scene, flags, report_name = CASES[name]
            log = case_dir / "run.log"
            command = common + ([] if args.visual else ["--headless"])
            command += ["--fixed-fps", "60", "--quit-after", "60000"] + scene + ["--"] + flags
            started = time.monotonic()
            code = run_process(command, log, env, args.timeout)
            log_text = log.read_text(encoding="utf-8", errors="replace")
            report_path = case_dir / report_name
            report = {}
            if report_path.is_file():
                try:
                    report = json.loads(report_path.read_text(encoding="utf-8"))
                except (ValueError, OSError):
                    pass
            errors = ERRORS.search(log_text) is not None
            passed = code == 0 and report.get("passed") is True and not report.get("failures") and not errors
            result = {"case": name, "repeat": repetition + 1, "passed": passed, "exit_code": code,
                      "checks": len(report.get("checks", [])), "failures": report.get("failures", []),
                      "runtime_errors": errors, "shutdown_warnings": bool(SHUTDOWN.search(log_text)),
                      "seconds": round(time.monotonic() - started, 2), "report": str(report_path), "log": str(log)}
            results.append(result)
            print(f"{'PASS' if passed else 'FAIL'} {name}: {result['checks']} checks ({result['seconds']}s)", flush=True)
    summary = {"passed": all(item["passed"] for item in results), "visual": args.visual,
               "results": results, "note": "Fixed simulation timing is not a graphics performance benchmark."}
    (output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"Report: {output / 'summary.json'}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
