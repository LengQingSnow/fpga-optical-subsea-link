import json
import tempfile
import unittest
import zlib
from pathlib import Path

from tools.prepare_dataset import (
    IMAGE_BASE,
    IMAGE_BYTES,
    IMAGE_COUNT,
    WAVEFORM_BASE,
    WAVEFORM_BYTES,
    build_descriptor,
    discover_raw_images,
    parse_rgb888_mem,
    parse_s16_mem,
    prepare_dataset,
)


class PrepareDatasetTests(unittest.TestCase):
    def test_rgb888_lines_become_r_g_b_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.mem"
            path.write_text("41C23C\nA3B9A8\n", encoding="ascii")
            self.assertEqual(
                parse_rgb888_mem(path),
                bytes([0x41, 0xC2, 0x3C, 0xA3, 0xB9, 0xA8]),
            )

    def test_signed_16_bit_lines_use_network_byte_order(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "wave.mem"
            path.write_text("FFFB\n0001\n8000\n", encoding="ascii")
            self.assertEqual(
                parse_s16_mem(path),
                bytes([0xFF, 0xFB, 0x00, 0x01, 0x80, 0x00]),
            )

    def test_invalid_mem_word_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.mem"
            path.write_text("12345\n", encoding="ascii")
            with self.assertRaisesRegex(ValueError, "line 1"):
                parse_rgb888_mem(path)

    def test_raw_images_are_sorted_numerically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("10_raw.mem", "2_raw.mem", "1_raw.mem"):
                (root / name).write_text("000000\n", encoding="ascii")
            self.assertEqual(
                [path.name for path in discover_raw_images(root)],
                ["1_raw.mem", "2_raw.mem", "10_raw.mem"],
            )

    def test_descriptor_is_little_endian_axi_words_and_ready_last(self):
        image_crcs = [index + 1 for index in range(IMAGE_COUNT)]
        descriptor = build_descriptor(image_crcs, 0xA1B2C3D4)
        self.assertEqual(len(descriptor), 256)
        self.assertEqual(descriptor[0:4], b"AXDD")
        self.assertEqual(
            int.from_bytes(descriptor[8:12], "little"), IMAGE_BASE
        )
        self.assertEqual(
            int.from_bytes(descriptor[12:16], "little"),
            IMAGE_COUNT * IMAGE_BYTES,
        )
        self.assertEqual(
            int.from_bytes(descriptor[16:20], "little"), WAVEFORM_BASE
        )
        self.assertEqual(
            int.from_bytes(descriptor[20:24], "little"), WAVEFORM_BYTES
        )
        self.assertEqual(
            int.from_bytes(descriptor[24:28], "little"), IMAGE_COUNT
        )
        self.assertEqual(
            int.from_bytes(descriptor[28:32], "little"), 0x00000003
        )
        self.assertEqual(
            int.from_bytes(descriptor[32:36], "little"), 1
        )
        self.assertEqual(
            int.from_bytes(descriptor[32 + 44 * 4:36 + 44 * 4], "little"),
            45,
        )
        self.assertEqual(
            int.from_bytes(descriptor[212:216], "little"), 0xA1B2C3D4
        )

    def test_full_prepare_produces_expected_lengths_and_crcs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image_root = root / "images"
            image_root.mkdir()
            pixels = ["010203", "A0B0C0"]
            for index in range(1, IMAGE_COUNT + 1):
                (image_root / f"{index}_raw.mem").write_text(
                    "\n".join(pixels) + "\n", encoding="ascii"
                )
            waveform_path = root / "waveform.mem"
            waveform_path.write_text("FFFB\n0001\n", encoding="ascii")
            output_root = root / "out"

            manifest = prepare_dataset(
                image_root=image_root,
                waveform_path=waveform_path,
                output_root=output_root,
                expected_pixels_per_image=2,
                expected_waveform_samples=2,
            )

            image_bytes = bytes.fromhex("010203A0B0C0")
            waveform_bytes = bytes.fromhex("FFFB0001")
            self.assertEqual(
                (output_root / "images_rgb888.bin").stat().st_size,
                IMAGE_COUNT * len(image_bytes),
            )
            self.assertEqual(
                (output_root / "waveform_bhz_int16.bin").read_bytes(),
                waveform_bytes,
            )
            self.assertEqual(
                manifest["images"][0]["crc32"],
                f"{zlib.crc32(image_bytes) & 0xFFFFFFFF:08X}",
            )
            self.assertEqual(
                manifest["waveform"]["crc32"],
                f"{zlib.crc32(waveform_bytes) & 0xFFFFFFFF:08X}",
            )
            saved = json.loads(
                (output_root / "manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(saved, manifest)


if __name__ == "__main__":
    unittest.main()
