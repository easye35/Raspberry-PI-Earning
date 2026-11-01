import os
import tempfile
import unittest

from earnings.app import earnings_logic as logic


class EarnAppStatusTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.earnapp_dir = os.path.join(self.temp_dir.name, "earnapp")
        self.proc_dir = os.path.join(self.temp_dir.name, "proc")
        os.makedirs(self.earnapp_dir)
        os.makedirs(self.proc_dir)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_not_installed_when_uuid_is_missing(self):
        self.assertEqual(
            logic.get_earnapp_status(self.earnapp_dir, self.proc_dir),
            {"installed": False, "running": False},
        )

    def test_running_when_host_process_exists(self):
        with open(os.path.join(self.earnapp_dir, "uuid"), "w", encoding="utf-8") as handle:
            handle.write("device-id")
        process_dir = os.path.join(self.proc_dir, "123")
        os.makedirs(process_dir)
        with open(os.path.join(process_dir, "comm"), "w", encoding="utf-8") as handle:
            handle.write("earnapp\n")

        self.assertEqual(
            logic.get_earnapp_status(self.earnapp_dir, self.proc_dir),
            {"installed": True, "running": True},
        )

    def test_not_running_when_host_process_is_absent(self):
        with open(os.path.join(self.earnapp_dir, "uuid"), "w", encoding="utf-8") as handle:
            handle.write("device-id")

        self.assertEqual(
            logic.get_earnapp_status(self.earnapp_dir, self.proc_dir),
            {"installed": True, "running": False},
        )

    def test_reports_missing_host_proc_directory(self):
        with open(os.path.join(self.earnapp_dir, "uuid"), "w", encoding="utf-8") as handle:
            handle.write("device-id")

        with self.assertRaises(FileNotFoundError):
            logic.get_earnapp_status(
                self.earnapp_dir,
                os.path.join(self.temp_dir.name, "missing"),
            )


if __name__ == "__main__":
    unittest.main()
