"""Mocked read-only status checks; no SSH, Nix or systemd required."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StatusTest(unittest.TestCase):
    def invoke(self, mode="same", unit="present", status=0, query=0, show=0):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            commands = {
                "sudo": '#!/bin/sh\nexec "$@"\n',
                "systemctl": """#!/bin/sh
case "$1" in
list-units) [ "$QUERY" = 0 ] || exit "$QUERY"
  [ "$UNIT" = absent ] || echo fleet-remote-activation.service ;;
status) echo "activation status"; exit "$STATUS" ;;
show) echo "Result=success"; exit "$SHOW" ;;
*) exit 99 ;;
esac
""",
                "readlink": """#!/bin/sh
case "$MODE:$2" in
missing:/run/booted-system/*) exit 1 ;;
malformed:*) echo /not/a/store/path; exit 0 ;;
changed:/nix/var/nix/profiles/system/kernel)
 echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-linux/kernel; exit 0 ;;
esac
echo "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-system/${2##*/}"
""",
                "uname": '#!/bin/sh\necho 6.12.mock\n',
                "ssh": '#!/bin/sh\nfor arg do command=$arg; done\nexec sh -c "$command"\n',
            }
            for name, content in commands.items():
                (path / name).write_text(content)
                (path / name).chmod(0o755)
            env = dict(os.environ, PATH=f"{path}:{os.environ['PATH']}",
                       MODE=mode, UNIT=unit, STATUS=str(status), QUERY=str(query),
                       SHOW=str(show))
            return subprocess.run(
                ["sh", "scripts/remote-activation.sh", "status", "mock-host", ""],
                cwd=ROOT, env=env, capture_output=True, text=True)

    def test_unchanged(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Reboot required: NO", result.stdout)
        self.assertIn("Running kernel version: 6.12.mock", result.stdout)
        self.assertIn("running is not complete", result.stdout)

    def test_changed(self):
        result = self.invoke(mode="changed")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Reboot required: YES", result.stdout)
        self.assertIn("Changed boot components: kernel\n", result.stdout)
        self.assertIn("/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-linux/kernel",
                      result.stdout)

    def test_unknown(self):
        for mode in ("missing", "malformed"):
            with self.subTest(mode=mode):
                result = self.invoke(mode=mode)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Reboot required: UNKNOWN", result.stdout)
                self.assertNotIn("Reboot required: NO", result.stdout)

    def test_query_failures(self):
        for kwargs, code in ((dict(query=17), 17), (dict(show=18), 18)):
            with self.subTest(kwargs=kwargs):
                result = self.invoke(**kwargs)
                self.assertEqual(result.returncode, code)
                self.assertIn("Reboot required: NO", result.stdout)
                if "query" in kwargs:
                    self.assertNotIn("unit: absent", result.stdout)

    def test_absent_still_reports(self):
        result = self.invoke(unit="absent", mode="changed")
        self.assertEqual(result.returncode, 0)
        self.assertIn("unit: absent", result.stdout)
        self.assertIn("Reboot required: YES", result.stdout)

    def test_failed_still_reports(self):
        result = self.invoke(status=3, mode="changed")
        self.assertEqual(result.returncode, 3)
        self.assertIn("activation status", result.stdout)
        self.assertIn("Reboot required: YES", result.stdout)

    def test_ssh_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            ssh = Path(directory) / "ssh"
            ssh.write_text("#!/bin/sh\nexit 255\n")
            ssh.chmod(0o755)
            result = subprocess.run(
                ["sh", "scripts/remote-activation.sh", "status", "mock-host", ""],
                cwd=ROOT, env=dict(os.environ, PATH=f"{directory}:{os.environ['PATH']}"),
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 255)
            self.assertNotIn("Reboot required: NO", result.stdout)


if __name__ == "__main__":
    unittest.main()
