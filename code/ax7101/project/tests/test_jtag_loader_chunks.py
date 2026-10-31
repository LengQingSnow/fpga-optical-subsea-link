import tempfile
import unittest
from pathlib import Path

from tools.load_dataset_jtag import (
    AxiOperation,
    build_load_plan,
    iter_axi_chunks,
    pack_axi64_words,
    render_plan_line,
)


class JtagLoaderChunkTests(unittest.TestCase):
    def test_pack_axi64_words_uses_little_endian_axi_lanes(self):
        words = pack_axi64_words(bytes(range(16)))
        self.assertEqual(
            words,
            ("0706050403020100", "0F0E0D0C0B0A0908"),
        )

    def test_chunks_are_bounded_aligned_and_round_trip(self):
        payload = bytes((index * 17) & 0xFF for index in range(4101))
        chunks = list(iter_axi_chunks(0x00100000, payload, max_beats=256))

        self.assertEqual([chunk.address for chunk in chunks],
                         [0x00100000, 0x00100800, 0x00101000])
        self.assertEqual([chunk.valid_bytes for chunk in chunks],
                         [2048, 2048, 5])
        self.assertTrue(all(chunk.beats <= 256 for chunk in chunks))
        reconstructed = b"".join(chunk.data[:chunk.valid_bytes]
                                 for chunk in chunks)
        self.assertEqual(reconstructed, payload)
        self.assertEqual(len(chunks[-1].data), 8)

    def test_unaligned_start_address_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "8-byte aligned"):
            list(iter_axi_chunks(3, b"abc"))

    def test_load_plan_publishes_ready_descriptor_last(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset = Path(temp_dir)
            not_ready = bytearray(256)
            ready = bytearray(256)
            not_ready[0:8] = b"AXDD\x01\x00\x00\x00"
            ready[0:8] = not_ready[0:8]
            ready[28:32] = (3).to_bytes(4, "little")
            (dataset / "descriptor_not_ready.bin").write_bytes(not_ready)
            (dataset / "descriptor_ready.bin").write_bytes(ready)
            (dataset / "images_rgb888.bin").write_bytes(bytes(range(19)))
            (dataset / "waveform_bhz_int16.bin").write_bytes(bytes(range(11)))

            operations = build_load_plan(dataset, max_beats=2,
                                         strict_lengths=False)

        phases = [(operation.kind, operation.label)
                  for operation in operations]
        self.assertEqual(phases[0], ("write", "descriptor_not_ready"))
        self.assertIn(("read", "images_verify"), phases)
        self.assertIn(("read", "waveform_verify"), phases)
        ready_write = phases.index(("write", "descriptor_ready"))
        self.assertGreater(
            ready_write,
            max(index for index, phase in enumerate(phases)
                if phase[0] == "read" and phase[1] !=
                "descriptor_ready_verify"),
        )
        self.assertEqual(phases[-1], ("read", "descriptor_ready_verify"))
        self.assertTrue(
            all(label in {"descriptor_ready", "descriptor_ready_verify"}
                for _, label in phases[ready_write:])
        )

    def test_plan_line_contains_address_beats_and_axi_words(self):
        chunk = next(iter(iter_axi_chunks(0x20, b"ABCDEFGH")))
        operation = AxiOperation("write", "sample", chunk)
        self.assertEqual(
            render_plan_line(operation),
            "W|sample|00000020|1|4847464544434241",
        )


if __name__ == "__main__":
    unittest.main()
