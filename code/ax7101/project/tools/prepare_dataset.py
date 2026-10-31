#!/usr/bin/env python3
"""Convert ax7101 dataset MEM files into compact DDR/JTAG load images."""

from __future__ import annotations

import argparse
import json
import re
import struct
import zlib
from pathlib import Path
from typing import Iterable

DESCRIPTOR_BASE = 0x00000000
IMAGE_BASE = 0x00100000
WAVEFORM_BASE = 0x02000000
IMAGE_COUNT = 3
IMAGE_WIDTH = 160
IMAGE_HEIGHT = 120
IMAGE_BYTES = IMAGE_WIDTH * IMAGE_HEIGHT * 3
WAVEFORM_SAMPLES = 11_200
WAVEFORM_BYTES = WAVEFORM_SAMPLES * 2
DESCRIPTOR_BYTES = 256

_RAW_IMAGE_PATTERN = re.compile(r"^([1-9][0-9]*)_raw\.mem$")


def _parse_mem_words(path: Path, hex_digits: int) -> Iterable[int]:
    maximum = (1 << (hex_digits * 4)) - 1
    with path.open("r", encoding="ascii") as source:
        for line_number, raw_line in enumerate(source, start=1):
            word = raw_line.strip()
            if not word:
                raise ValueError(f"{path}: line {line_number} is empty")
            if len(word) != hex_digits:
                raise ValueError(
                    f"{path}: line {line_number} must contain "
                    f"{hex_digits} hex digits"
                )
            try:
                value = int(word, 16)
            except ValueError as error:
                raise ValueError(
                    f"{path}: line {line_number} is not hexadecimal"
                ) from error
            if value < 0 or value > maximum:
                raise ValueError(f"{path}: line {line_number} is out of range")
            yield value


def parse_rgb888_mem(path: Path) -> bytes:
    output = bytearray()
    for value in _parse_mem_words(Path(path), 6):
        output.extend(value.to_bytes(3, "big"))
    return bytes(output)


def parse_s16_mem(path: Path) -> bytes:
    output = bytearray()
    for value in _parse_mem_words(Path(path), 4):
        output.extend(value.to_bytes(2, "big"))
    return bytes(output)


def discover_raw_images(image_root: Path) -> list[Path]:
    numbered: list[tuple[int, Path]] = []
    for path in Path(image_root).glob("*_raw.mem"):
        match = _RAW_IMAGE_PATTERN.match(path.name)
        if match:
            numbered.append((int(match.group(1)), path))
    return [path for _, path in sorted(numbered)]


def crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


def build_descriptor(
    image_crcs: list[int],
    waveform_crc: int,
    ready_flags: int = 0x00000003,
) -> bytes:
    if len(image_crcs) != IMAGE_COUNT:
        raise ValueError(f"expected {IMAGE_COUNT} image CRC values")

    descriptor = bytearray(DESCRIPTOR_BYTES)
    descriptor[0:4] = b"AXDD"
    descriptor[4:8] = bytes([1, 0, 0, 0])
    struct.pack_into("<I", descriptor, 8, IMAGE_BASE)
    struct.pack_into("<I", descriptor, 12, IMAGE_COUNT * IMAGE_BYTES)
    struct.pack_into("<I", descriptor, 16, WAVEFORM_BASE)
    struct.pack_into("<I", descriptor, 20, WAVEFORM_BYTES)
    struct.pack_into("<I", descriptor, 24, IMAGE_COUNT)
    struct.pack_into("<I", descriptor, 28, ready_flags)
    for index, image_crc in enumerate(image_crcs):
        struct.pack_into("<I", descriptor, 32 + index * 4, image_crc)
    struct.pack_into("<I", descriptor, 212, waveform_crc)
    struct.pack_into("<I", descriptor, 216, IMAGE_BYTES)
    struct.pack_into("<I", descriptor, 220, WAVEFORM_SAMPLES)
    return bytes(descriptor)


def prepare_dataset(
    image_root: Path,
    waveform_path: Path,
    output_root: Path,
    expected_pixels_per_image: int = IMAGE_WIDTH * IMAGE_HEIGHT,
    expected_waveform_samples: int = WAVEFORM_SAMPLES,
) -> dict:
    image_paths = discover_raw_images(image_root)
    expected_indices = list(range(1, IMAGE_COUNT + 1))
    actual_indices = [
        int(_RAW_IMAGE_PATTERN.match(path.name).group(1)) for path in image_paths
    ]
    if actual_indices != expected_indices:
        raise ValueError(
            f"raw image set must contain numeric images 1..{IMAGE_COUNT}; "
            f"found {actual_indices}"
        )

    output_root = Path(output_root)
    output_root.mkdir(parents=True, exist_ok=True)

    image_output = output_root / "images_rgb888.bin"
    image_records = []
    image_crcs = []
    with image_output.open("wb") as combined_images:
        for image_index, image_path in enumerate(image_paths, start=1):
            image_data = parse_rgb888_mem(image_path)
            expected_length = expected_pixels_per_image * 3
            if len(image_data) != expected_length:
                raise ValueError(
                    f"{image_path}: expected {expected_length} bytes, "
                    f"found {len(image_data)}"
                )
            image_crc = crc32(image_data)
            image_crcs.append(image_crc)
            combined_images.write(image_data)
            image_records.append(
                {
                    "id": image_index,
                    "source": image_path.name,
                    "ddr_address": f"{IMAGE_BASE + (image_index - 1) * expected_length:08X}",
                    "length": expected_length,
                    "crc32": f"{image_crc:08X}",
                }
            )

    waveform_data = parse_s16_mem(waveform_path)
    expected_waveform_length = expected_waveform_samples * 2
    if len(waveform_data) != expected_waveform_length:
        raise ValueError(
            f"{waveform_path}: expected {expected_waveform_length} bytes, "
            f"found {len(waveform_data)}"
        )
    waveform_crc = crc32(waveform_data)
    waveform_output = output_root / "waveform_bhz_int16.bin"
    waveform_output.write_bytes(waveform_data)

    descriptor = build_descriptor(image_crcs, waveform_crc)
    (output_root / "descriptor_ready.bin").write_bytes(descriptor)
    (output_root / "descriptor_not_ready.bin").write_bytes(
        build_descriptor(image_crcs, waveform_crc, ready_flags=0)
    )
    (output_root / "image_crc32.mem").write_text(
        "".join(f"{value:08X}\n" for value in image_crcs),
        encoding="ascii",
    )

    manifest = {
        "format": "AX7101_DUAL_DATASET_DDR_V1",
        "descriptor": {
            "ddr_address": f"{DESCRIPTOR_BASE:08X}",
            "length": DESCRIPTOR_BYTES,
        },
        "image_region": {
            "ddr_address": f"{IMAGE_BASE:08X}",
            "length": IMAGE_COUNT * expected_pixels_per_image * 3,
            "image_count": IMAGE_COUNT,
            "image_width": IMAGE_WIDTH,
            "image_height": IMAGE_HEIGHT,
            "pixel_format": "RGB888",
        },
        "images": image_records,
        "waveform": {
            "source": Path(waveform_path).name,
            "ddr_address": f"{WAVEFORM_BASE:08X}",
            "length": expected_waveform_length,
            "samples": expected_waveform_samples,
            "sample_format": "signed_int16_big_endian",
            "crc32": f"{waveform_crc:08X}",
        },
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> int:
    project_root = Path(__file__).resolve().parents[1]
    dataset_root = project_root.parent / "dataset" / "prepared_ax7101_trim160s"
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--image-root",
        type=Path,
        default=dataset_root / "images_mem_rgb888",
    )
    parser.add_argument(
        "--waveform",
        type=Path,
        default=dataset_root / "waveform_bhz_int16.mem",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=project_root / "generated" / "dataset",
    )
    args = parser.parse_args()
    manifest = prepare_dataset(args.image_root, args.waveform, args.output)
    print(
        "PREPARED "
        f"images={manifest['image_region']['length']} "
        f"waveform={manifest['waveform']['length']} "
        f"output={args.output.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
