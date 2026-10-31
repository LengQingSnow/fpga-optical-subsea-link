"""Offline packaging checks. No instrument API, network, or generated files."""
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import zlib
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def manifest_check(base):
    m = json.loads((base / "manifest.json").read_text(encoding="utf-8-sig"))
    for name, item in m["files"].items():
        p = base / name
        assert p.stat().st_size == item["bytes"], (p, "size")
        assert digest(p).lower() == item["sha256"].lower(), (p, "SHA256")
    wave = (base / "waveform_bhz_int16.bin").read_bytes()
    assert len(wave) == m["waveform"]["length"] == 22400
    assert m["waveform"]["samples"] == 11200
    assert f"{zlib.crc32(wave) & 0xffffffff:08X}" == m["waveform"]["crc32"]
    assert digest(base / "waveform_bhz_int16.mem").lower() == m["waveform"]["source_sha256"].lower()
    mem = b"".join(int(v, 16).to_bytes(2, "big") for v in (base / "waveform_bhz_int16.mem").read_text().split())
    assert mem == wave, "Waveform MEM/BIN mismatch"
    images = b""
    for image in m["images"]:
        content = b"".join(int(v, 16).to_bytes(3, "big") for v in (base / image["mem_file"]).read_text().split())
        assert len(content) == 160*120*3
        assert f"{zlib.crc32(content) & 0xffffffff:08X}" == image["crc32"]
        images += content
    assert images == (base / "images_rgb888.bin").read_bytes()
    return m

def main():
    canonical = ROOT / "code/ax7101/dataset/prepared_ax7101_trim160s"
    gui = ROOT / "r_matlab/dataset2/prepared_ax7101_trim160s"
    manifest_check(canonical); manifest_check(gui)
    for p in canonical.rglob("*"):
        if p.is_file():
            assert (gui/p.relative_to(canonical)).read_bytes() == p.read_bytes(), "Dataset copies differ"
    # Import planner only, never invoke its hardware main().
    project = ROOT / "code/ax7101/project"
    sys.path.insert(0, str(project))
    spec = importlib.util.spec_from_file_location("release_loader", project/"tools/load_dataset_jtag.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    plan = module.build_load_plan(canonical)
    assert any(op.kind == "write" for op in plan) and any(op.kind == "read" for op in plan)
    for item in json.loads((ROOT/"docs/firmware_manifest.json").read_text(encoding="utf-8"))["files"]:
        p = ROOT/item["path"]
        assert p.stat().st_size == item["bytes"] and digest(p) == item["sha256"], item["path"]
    legacy = json.loads((ROOT/"docs/legacy_dsp_manifest.json").read_text())["sha256"]
    for name, expected in legacy.items():
        assert digest(ROOT/name) == expected, "Legacy DSP changed: "+name
    for forbidden in ["+rf47page5wdm", "rf47_spectrum_analyze.m", "rf47_page5_wdm_dsp.m"]:
        assert not (ROOT/"r_matlab/matlab"/forbidden).exists(), "New private DSP must not be added"
    essential = [
        "code/da_project/doc/rfevm_rf_adaloop/rfevm_rf_adaloop/rfevm_rf_adaloop.srcs/sources_1/bd/system/system.bd",
        "code/da_project/doc/rfevm_rf_adaloop/rfevm_rf_adaloop/rfevm_rf_adaloop.srcs/sources_1/new/up_axi.v",
        "code/da_project/doc/rfevm_rf_adaloop/rfevm_rf_adaloop/rfevm_rf_adaloop.srcs/sources_1/new/user_control.v",
        "code/ax7101/project/ip/camera/afifo_16i_64o_512/afifo_16i_64o_512.xci",
        "code/ax7101/project/ip/camera/afifo_64i_16o_128/afifo_64i_16o_128.xci",
        "code/ax7101/project/ip/camera/video_pll/video_pll.xci",
        "code/da_project/porject/vitis/output/psu_init.tcl",
        "scripts/launch_support/workflow.cs", "scripts/launch_support/rf47_mode.tcl",
        "scripts/launch_support/alignment_core.cs",
    ]
    for name in essential:
        assert (ROOT/name).is_file(), "Missing build/runtime source: "+name
    if (ROOT/".git").exists():
        args = ["git","-c","safe.directory="+ROOT.as_posix(),"-c","core.longpaths=true","-C",str(ROOT)]
        raw = subprocess.check_output(args+["ls-files","--cached","--others","--exclude-standard","-z"])
        names = sorted(set(x.decode("utf-8") for x in raw.split(b"\0") if x))
        for name in essential + list(legacy):
            assert name in names, "Dependency excluded from Git: "+name
        total = 0
        for name in names:
            p=ROOT/name; n=p.stat().st_size;total+=n
            assert n<=100*1024**2, "GitHub regular-file size limit: "+name
            assert p.suffix.lower() not in {".lic",".pem",".key"}, "Review private credential file: "+name
            if p.suffix.lower() in {".m",".ps1",".py",".tcl",".cs",".bif"}:
                text=p.read_text(encoding="utf-8-sig",errors="replace")
                assert not re.search(r"(?<![A-Za-z])[C-Z]:[\\/]",text), "Fixed machine path in published code: "+name
        print(f"GIT_FILES={len(names)} SIZE_MIB={total/1024**2:.2f}")
    print(f"PASS: dataset MEM/BIN/CRC/hash, copies, {len(legacy)} legacy DSP publication hashes (path/entry-only migration), firmware, build inputs, offline DDR plan ({len(plan)} ops).")
    print("THIS CHECK IS OFFLINE. MATLAB/RTL results are recorded separately in build/evidence; no synthesis or live scope/JTAG/BER in this pass.")
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
