"""Local-only invocation checks; never contacts a host or runs systemd."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RemoteActivationTest(unittest.TestCase):
    def invoke(self, target, failure=0):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "ssh").write_text(
                '#!/bin/sh\nprintf "%s\\n" "$@" > "$SSH_ARGS"\n'
                'for arg do command=$arg; done\nexec sh -c "$command"\n'
            )
            (path / "sudo").write_text('#!/bin/sh\nexec "$@"\n')
            (path / "systemd-run").write_text(
                '#!/usr/bin/env python3\nimport json, os, sys\n'
                'open(os.environ["RUN_ARGS"], "w").write(json.dumps(sys.argv[1:]))\n'
                'sys.exit(int(os.environ["FAILURE"]))\n'
            )
            for name in ("ssh", "sudo", "systemd-run"):
                (path / name).chmod(0o755)
            flake = "github:owner/repo/branch with 'quotes'; $HOME"
            env = dict(os.environ, PATH=f"{path}:{os.environ['PATH']}",
                       SSH_ARGS=str(path / "ssh.args"), RUN_ARGS=str(path / "run.args"),
                       FAILURE=str(failure), REMOTE_FLAKE=flake.replace("$", "$$"))
            result = subprocess.run(
                ["make", "-s", target, "REMOTE=admin@example", "HOST=other",
                 "REMOTE_TTY=-tt"],
                cwd=ROOT, env=env, text=True, capture_output=True,
            )
            args = json.loads((path / "run.args").read_text())
            self.assertEqual((path / "ssh.args").read_text().splitlines()[:2],
                             ["-tt", "admin@example"])
            self.assertEqual(args, [
                "--system", "--no-block", "--unit=fleet-remote-activation.service",
                "--property=Type=exec", "--property=RemainAfterExit=yes",
                "--property=StandardOutput=journal", "--property=StandardError=journal",
                "--setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin",
                "--setenv=HOME=/root",
                "--", "/run/current-system/sw/bin/nixos-rebuild", target.removeprefix("remote-"),
                "--flake", flake + "#other", "--refresh",
            ])
            return result

    def test_switch(self):
        result = self.invoke("remote-switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("deployment result is not yet known", result.stdout)
        self.assertIn("make remote-activation-clear", result.stdout)
        self.assertIn("Clear refuses running or queued work", result.stdout)

    def test_test(self):
        self.assertEqual(self.invoke("remote-test").returncode, 0)

    def test_launch_failure(self):
        result = self.invoke("remote-switch", failure=17)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Error 17", result.stderr)
        self.assertNotIn("Launch request accepted", result.stdout)
        self.assertIn("may already be running", result.stderr)


class RemoteActivationClearTest(unittest.TestCase):
    unit = "fleet-remote-activation.service"

    def invoke(self, active="active", sub="exited", job="", jobs="",
               absent=False, failure="", result="success", code="1", status="0"):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "ssh").write_text(
                '#!/bin/sh\nprintf "%s\\n" "$@" > "$SSH_ARGS"\n'
                'if [ "$FAILURE" = ssh ]; then exit 23; fi\n'
                'for arg do command=$arg; done\nexec sh -c "$command"\n')
            (path / "sudo").write_text('#!/bin/sh\nexec "$@"\n')
            (path / "systemctl").write_text(
                '#!/usr/bin/env python3\nimport json, os, sys\n'
                'with open(os.environ["CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                'action=sys.argv[1]\n'
                'if action == os.environ["FAILURE"]: sys.exit(19)\n'
                'if action == "list-jobs": print(os.environ["JOBS"], end="")\n'
                'if action == "list-units": print(os.environ["UNITS"], end="")\n'
                'if action == "show": print(os.environ["STATE"])\n')
            for name in ("ssh", "sudo", "systemctl"):
                (path / name).chmod(0o755)
            env = dict(os.environ, PATH=f"{path}:{os.environ['PATH']}",
                       SSH_ARGS=str(path / "ssh.args"), CALLS=str(path / "calls"),
                       FAILURE=failure, JOBS=jobs,
                       UNITS="" if absent else self.unit + " loaded active exited\n",
                       STATE=f"LoadState=loaded\nActiveState={active}\nSubState={sub}\n"
                             f"Result={result}\nExecMainCode={code}\nExecMainStatus={status}\nJob={job}")
            proc = subprocess.run(
                ["make", "-s", "remote-activation-clear", "HOST=cobra",
                 "REMOTE=admin@host'quoted", "REMOTE_TTY=-T -o BatchMode=yes"],
                cwd=ROOT, env=env, text=True, capture_output=True)
            self.assertEqual((path / "ssh.args").read_text().splitlines(),
                             ["-T", "-o", "BatchMode=yes", "admin@host'quoted", "sh -s"])
            calls = ([json.loads(line) for line in (path / "calls").read_text().splitlines()]
                     if (path / "calls").exists() else [])
            return proc, calls

    def test_ssh_error(self):
        proc, calls = self.invoke(failure="ssh")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Error 23", proc.stderr)
        self.assertEqual(calls, [])

    def test_success_and_exact_queries(self):
        proc, calls = self.invoke()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(calls, [
            ["list-jobs", "--no-legend", "--no-pager"],
            ["list-units", "--all", "--plain", "--no-legend", "--no-pager", self.unit],
            ["show", self.unit, "--property=LoadState,ActiveState,SubState,Result,ExecMainCode,ExecMainStatus,Job"],
            ["stop", self.unit]])

    def test_failed(self):
        proc, calls = self.invoke(active="failed", sub="failed", result="exit-code", status="1")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(calls[-1], ["reset-failed", self.unit])

    def test_absent(self):
        proc, calls = self.invoke(absent=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(len(calls), 2)

    def test_refusals(self):
        cases = [
            dict(active="active", sub="running"),
            dict(active="activating", sub="start"),
            dict(active="deactivating", sub="stop"),
            dict(active="reloading", sub="reload"),
            dict(active="inactive", sub="dead"),
            dict(job="12"),
            dict(jobs=f"12 {self.unit} start waiting\n"),
            dict(result="exit-code"), dict(status="1"),
        ]
        for kwargs in cases:
            with self.subTest(**kwargs):
                proc, calls = self.invoke(**kwargs)
                self.assertNotEqual(proc.returncode, 0)
                self.assertFalse(any(c[0] in ("stop", "reset-failed") for c in calls))

    def test_query_and_mutation_errors(self):
        for action in ("list-jobs", "list-units", "show", "stop", "reset-failed"):
            with self.subTest(action=action):
                kwargs = dict(active="failed", sub="failed") if action == "reset-failed" else {}
                proc, calls = self.invoke(failure=action, **kwargs)
                self.assertNotEqual(proc.returncode, 0)
                self.assertIn("Error 19", proc.stderr)
                self.assertEqual(calls[-1][0], action)


if __name__ == "__main__":
    unittest.main()
