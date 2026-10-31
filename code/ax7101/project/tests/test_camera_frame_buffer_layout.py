import re
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CAMERA_SOURCE = PROJECT_ROOT / "src" / "dual_camera_vga_axi.v"
FRAME_WORDS = 76_800
AXI_BYTES_PER_BEAT = 8
AXI_BURST_BEATS = 64
AXI_PAGE_BYTES = 4096


class CameraFrameBufferLayoutTests(unittest.TestCase):
    def test_frame_buffers_are_disjoint_and_bursts_do_not_cross_4k(self):
        source = CAMERA_SOURCE.read_text(encoding="utf-8")
        addresses = {
            int(index): int(address)
            for index, address in re.findall(
                r"\.(?:read|write)_addr_([0-3])\s*"
                r"\(25'd([0-9]+)\s*\)",
                source,
            )
        }

        # Two camera instances each provide four distinct frame-buffer bases.
        all_addresses = [
            int(address)
            for address in re.findall(
                r"\.write_addr_[0-3]\s*\(25'd([0-9]+)\s*\)",
                source,
            )
        ]
        self.assertEqual(len(all_addresses), 8)
        self.assertEqual(len(set(all_addresses)), 8)
        self.assertEqual(len(addresses), 4)

        burst_bytes = AXI_BYTES_PER_BEAT * AXI_BURST_BEATS
        previous_end = None
        for word_address in sorted(all_addresses):
            byte_address = word_address * AXI_BYTES_PER_BEAT
            self.assertEqual(
                byte_address % AXI_PAGE_BYTES,
                0,
                f"frame buffer 0x{byte_address:08X} is not 4 KiB aligned",
            )
            self.assertEqual(byte_address % burst_bytes, 0)
            if previous_end is not None:
                self.assertGreaterEqual(byte_address, previous_end)
            previous_end = (
                byte_address + FRAME_WORDS * AXI_BYTES_PER_BEAT
            )


if __name__ == "__main__":
    unittest.main()
