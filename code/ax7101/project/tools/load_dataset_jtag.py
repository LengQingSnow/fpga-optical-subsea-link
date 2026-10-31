#!/usr/bin/env python3
"""Program ax7101 and load the prepared datasets into DDR3 through JTAG AXI."""

from __future__ import annotations

import argparse
import os
import shutil
import hashlib
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.prepare_dataset import (
    DESCRIPTOR_BASE,
    DESCRIPTOR_BYTES,
    IMAGE_BASE,
    IMAGE_BYTES,
    IMAGE_COUNT,
    WAVEFORM_BASE,
    WAVEFORM_BYTES,
)

AXI_BYTES = 8
DEFAULT_MAX_BEATS = 256


@dataclass(frozen=True)
class AxiChunk:
    address: int
    data: bytes
    valid_bytes: int

    @property
    def beats(self) -> int:
        return len(self.data) // AXI_BYTES

    @property
    def words(self) -> tuple[str, ...]:
        return pack_axi64_words(self.data)


@dataclass(frozen=True)
class AxiOperation:
    kind: str
    label: str
    chunk: AxiChunk


def pack_axi64_words(data: bytes) -> tuple[str, ...]:
    if len(data) % AXI_BYTES:
        raise ValueError("AXI data must contain complete 64-bit beats")
    return tuple(
        data[offset:offset + AXI_BYTES][::-1].hex().upper()
        for offset in range(0, len(data), AXI_BYTES)
    )


def iter_axi_chunks(
    start_address: int,
    data: bytes,
    max_beats: int = DEFAULT_MAX_BEATS,
) -> Iterable[AxiChunk]:
    if start_address % AXI_BYTES:
        raise ValueError("AXI start address must be 8-byte aligned")
    if max_beats < 1 or max_beats > 256:
        raise ValueError("max_beats must be in the range 1..256")

    chunk_bytes = max_beats * AXI_BYTES
    for offset in range(0, len(data), chunk_bytes):
        valid = data[offset:offset + chunk_bytes]
        padded_length = (
            (len(valid) + AXI_BYTES - 1) // AXI_BYTES
        ) * AXI_BYTES
        padded = valid.ljust(padded_length, b"\x00")
        yield AxiChunk(start_address + offset, padded, len(valid))


def _validate_descriptor(data: bytes, expected_ready: int) -> None:
    if len(data) != DESCRIPTOR_BYTES:
        raise ValueError(
            f"descriptor must be {DESCRIPTOR_BYTES} bytes, found {len(data)}"
        )
    if data[0:4] != b"AXDD" or data[4:8] != b"\x01\x00\x00\x00":
        raise ValueError("descriptor magic/version is invalid")
    ready = int.from_bytes(data[28:32], "little")
    if ready != expected_ready:
        raise ValueError(
            f"descriptor ready flags must be {expected_ready}, found {ready}"
        )


def _append_region(
    operations: list[AxiOperation],
    kind: str,
    label: str,
    address: int,
    data: bytes,
    max_beats: int,
) -> None:
    for chunk in iter_axi_chunks(address, data, max_beats):
        operations.append(AxiOperation(kind, label, chunk))


def build_load_plan(
    dataset_root: Path,
    max_beats: int = DEFAULT_MAX_BEATS,
    strict_lengths: bool = True,
) -> list[AxiOperation]:
    dataset_root = Path(dataset_root)
    descriptor_not_ready = (
        dataset_root / "descriptor_not_ready.bin"
    ).read_bytes()
    descriptor_ready = (dataset_root / "descriptor_ready.bin").read_bytes()
    images = (dataset_root / "images_rgb888.bin").read_bytes()
    waveform = (dataset_root / "waveform_bhz_int16.bin").read_bytes()

    _validate_descriptor(descriptor_not_ready, 0)
    _validate_descriptor(descriptor_ready, 3)
    if strict_lengths:
        expected_images = IMAGE_COUNT * IMAGE_BYTES
        if len(images) != expected_images:
            raise ValueError(
                f"image region must be {expected_images} bytes, "
                f"found {len(images)}"
            )
        if len(waveform) != WAVEFORM_BYTES:
            raise ValueError(
                f"waveform region must be {WAVEFORM_BYTES} bytes, "
                f"found {len(waveform)}"
            )

    operations: list[AxiOperation] = []
    _append_region(
        operations, "write", "descriptor_not_ready",
        DESCRIPTOR_BASE, descriptor_not_ready, max_beats,
    )
    _append_region(
        operations, "read", "descriptor_not_ready_verify",
        DESCRIPTOR_BASE, descriptor_not_ready, max_beats,
    )
    _append_region(
        operations, "write", "images",
        IMAGE_BASE, images, max_beats,
    )
    _append_region(
        operations, "write", "waveform",
        WAVEFORM_BASE, waveform, max_beats,
    )
    _append_region(
        operations, "read", "images_verify",
        IMAGE_BASE, images, max_beats,
    )
    _append_region(
        operations, "read", "waveform_verify",
        WAVEFORM_BASE, waveform, max_beats,
    )
    _append_region(
        operations, "write", "descriptor_ready",
        DESCRIPTOR_BASE, descriptor_ready, max_beats,
    )
    _append_region(
        operations, "read", "descriptor_ready_verify",
        DESCRIPTOR_BASE, descriptor_ready, max_beats,
    )
    return operations


def render_plan_line(operation: AxiOperation) -> str:
    opcode = {"write": "W", "read": "R"}.get(operation.kind)
    if opcode is None:
        raise ValueError(f"unsupported AXI operation: {operation.kind}")
    return (
        f"{opcode}|{operation.label}|{operation.chunk.address:08X}|"
        f"{operation.chunk.beats}|{' '.join(operation.chunk.words)}"
    )


def write_plan(path: Path, operations: list[AxiOperation]) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as output:
        output.write("AX7101_JTAG_AXI_PLAN_V1\n")
        for operation in operations:
            output.write(render_plan_line(operation))
            output.write("\n")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    project_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dataset",
        type=Path,
        default=project_root.parent / "dataset" / "prepared_ax7101_trim160s",
    )
    parser.add_argument(
        "--bit",
        type=Path,
        default=project_root
        / "bitstream"
        / "ax7101_dual_dataset_udp.bit",
    )
    parser.add_argument(
        "--ltx",
        type=Path,
        default=project_root
        / "bitstream"
        / "ax7101_dual_dataset_udp.ltx",
    )
    parser.add_argument(
        "--vivado",
        type=Path,
        default=Path(os.environ.get("SMF_VIVADO") or shutil.which("vivado.bat") or "vivado.bat"),
    )
    parser.add_argument(
        "--plan-output",
        type=Path,
        default=project_root / "generated" / "jtag_load_plan.txt",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=project_root
        / "reports"
        / "hardware"
        / "dataset_load_report.json",
    )
    parser.add_argument("--max-beats", type=int, default=DEFAULT_MAX_BEATS)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    operations = build_load_plan(args.dataset, args.max_beats)
    write_plan(args.plan_output, operations)
    write_count = sum(op.kind == "write" for op in operations)
    read_count = sum(op.kind == "read" for op in operations)
    print(
        f"PLAN operations={len(operations)} writes={write_count} "
        f"reads={read_count} file={args.plan_output.resolve()}"
    )
    if args.dry_run:
        return 0

    for required in (args.vivado, args.bit):
        if not required.exists():
            raise FileNotFoundError(required)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    log_path = args.report.parent / "load_dataset_jtag.log"
    journal_path = args.report.parent / "load_dataset_jtag.jou"
    tcl_path = project_root / "scripts" / "load_dataset_jtag.tcl"
    start_time = time.monotonic()
    command = [
        str(args.vivado),
        "-mode", "batch",
        "-log", str(log_path),
        "-journal", str(journal_path),
        "-source", str(tcl_path),
        "-tclargs",
        str(args.plan_output.resolve()),
        str(args.bit.resolve()),
        str(args.ltx.resolve()),
    ]
    subprocess.run(command, cwd=project_root, check=True)
    elapsed_seconds = time.monotonic() - start_time

    image_path = args.dataset / "images_rgb888.bin"
    waveform_path = args.dataset / "waveform_bhz_int16.bin"
    report = {
        "format": "AX7101_JTAG_DATASET_LOAD_REPORT_V1",
        "result": "PASS",
        "bitstream": {
            "path": str(args.bit.resolve()),
            "sha256": _sha256(args.bit),
        },
        "images": {
            "bytes": image_path.stat().st_size,
            "sha256": _sha256(image_path),
            "ddr_address": f"{IMAGE_BASE:08X}",
        },
        "waveform": {
            "bytes": waveform_path.stat().st_size,
            "sha256": _sha256(waveform_path),
            "ddr_address": f"{WAVEFORM_BASE:08X}",
        },
        "transactions": {
            "write": write_count,
            "read_verify": read_count,
            "max_beats": args.max_beats,
        },
        "elapsed_seconds": round(elapsed_seconds, 3),
        "ready_published_after_readback": True,
    }
    args.report.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="ascii",
    )
    print(
        f"LOAD_PASS elapsed={elapsed_seconds:.3f}s "
        f"report={args.report.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
