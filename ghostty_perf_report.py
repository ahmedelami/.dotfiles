#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PerfEvent:
    ms_since_start: float
    label: str
    launch_ms: float
    extra: str


def read_latest_launch_ts_ns_from_launch_log(launch_log: Path) -> int | None:
    last: int | None = None
    needle = "| launcher:start |"
    ts_re = re.compile(r"launch_ts_ns=(\d+)")
    try:
        with launch_log.open("r", encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if needle not in line:
                    continue
                m = ts_re.search(line)
                if m:
                    last = int(m.group(1))
    except FileNotFoundError:
        return None
    return last


def read_latest_launch_ts_ns(perf_log: Path) -> int | None:
    last: int | None = None
    header_re = re.compile(r"launch_ts_ns=(\d+)")
    try:
        with perf_log.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                if not line.startswith("=== "):
                    continue
                m = header_re.search(line)
                if m:
                    last = int(m.group(1))
    except FileNotFoundError:
        return None
    return last


def parse_perf_section(perf_log: Path, launch_ts_ns: int) -> list[PerfEvent]:
    events: list[PerfEvent] = []
    header_re = re.compile(r"launch_ts_ns=(\d+)")
    in_section = False
    try:
        with perf_log.open("r", encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if line.startswith("=== "):
                    m = header_re.search(line)
                    in_section = bool(m and int(m.group(1)) == launch_ts_ns)
                    continue
                if not in_section:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 3:
                    continue
                if not parts[0].endswith("ms"):
                    continue
                if not parts[2].startswith("launch="):
                    continue
                try:
                    ms_since_start = float(parts[0].removesuffix("ms").strip())
                    label = parts[1]
                    launch_ms = float(parts[2].split("=", 1)[1].removesuffix("ms").strip())
                except Exception:
                    continue
                extra = " | ".join(parts[3:]).strip()
                events.append(PerfEvent(ms_since_start=ms_since_start, label=label, launch_ms=launch_ms, extra=extra))
    except FileNotFoundError:
        return []
    return events


def parse_launch_log(launch_log: Path, launch_ts_ns: int) -> dict[str, float | int | str]:
    out: dict[str, float | int | str] = {}
    needle = f"launch_ts_ns={launch_ts_ns}"
    try:
        with launch_log.open("r", encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if needle not in line:
                    continue
                # Leading token is always an absolute timestamp (ns).
                try:
                    ts_ns = int(line.split(" ", 1)[0])
                except Exception:
                    continue

                if "| launcher:open_to_launcher |" in line:
                    m = re.search(r"delta_ns=(\d+)", line)
                    if m:
                        out["open_to_launcher_ms"] = int(m.group(1)) / 1e6
                elif "| launcher:exec-tmux |" in line:
                    out["launcher_exec_tmux_ts_ns"] = ts_ns
                elif "| tmux:cmd:start |" in line:
                    out["tmux_cmd_start_ts_ns"] = ts_ns
                elif "| tmux:client-attached |" in line:
                    out["tmux_client_attached_ts_ns"] = ts_ns
                elif "| tmux:client-detached |" in line:
                    out["tmux_client_detached_ts_ns"] = ts_ns
                elif "| launcher:tmux_impl=" in line:
                    m = re.search(r"launcher:tmux_impl=([^ ]+)", line)
                    if m:
                        out["tmux_impl"] = m.group(1)
    except FileNotFoundError:
        return out
    return out


def parse_shell_log(shell_log: Path, launch_ts_ns: int) -> dict[str, int]:
    out: dict[str, int] = {}
    needle = f"launch_ts_ns={launch_ts_ns}"
    try:
        with shell_log.open("r", encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if needle not in line:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 2:
                    continue
                try:
                    ts_ns = int(parts[0])
                except Exception:
                    continue
                event = parts[1]
                out.setdefault(event, ts_ns)
    except FileNotFoundError:
        return out
    return out


def first_event(events: list[PerfEvent], label: str) -> PerfEvent | None:
    for ev in events:
        if ev.label == label:
            return ev
    return None


def fmt_ms(v: float | None) -> str:
    if v is None:
        return "n/a"
    return f"{v:.2f}ms"


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize latest Ghostty→tmux→nvim→toggleterm cold-start timing.")
    parser.add_argument("--launch", type=int, default=None, help="launch_ts_ns to report (defaults to latest in perf log)")
    args = parser.parse_args()

    home = Path(os.path.expanduser("~"))
    perf_log = home / ".local/state/nvim/humoodagen-perf.log"
    launch_log = home / ".local/state/humoodagen/ghostty-launch.log"
    shell_log = home / ".local/state/humoodagen/toggleterm-shell.log"

    launch_ts_ns = args.launch or read_latest_launch_ts_ns_from_launch_log(launch_log) or read_latest_launch_ts_ns(perf_log)
    if not launch_ts_ns:
        print(f"Could not find a launch_ts_ns in {perf_log}")
        return 1

    perf_events = parse_perf_section(perf_log, launch_ts_ns)
    launch_events = parse_launch_log(launch_log, launch_ts_ns)
    shell_events = parse_shell_log(shell_log, launch_ts_ns)

    perf_enabled = first_event(perf_events, "perf enabled")
    lazy_done = first_event(perf_events, "User LazyDone")
    vim_enter = first_event(perf_events, "VimEnter")
    ui_enter = first_event(perf_events, "UIEnter")
    tt_open_begin = first_event(perf_events, "toggleterm:startup:open_horizontal_in_win:begin")
    tt_open_done = first_event(perf_events, "toggleterm:startup:open_horizontal_in_win:done")
    tt_spawn_begin = first_event(perf_events, "toggleterm:term:spawn:begin")
    tt_spawn_done = first_event(perf_events, "toggleterm:term:spawn:done")
    tt_startup_done = first_event(perf_events, "toggleterm:startup:done")
    tt_stdout_first = first_event(perf_events, "toggleterm:stdout:first")
    tree_open_start = first_event(perf_events, "nvim-tree:open:start")
    tree_open_done = first_event(perf_events, "nvim-tree:open:done")

    nvim_init_start_launch_ms: float | None = None
    nvim_init_start_abs_ns: int | None = None
    if perf_enabled:
        # launch time when init.lua started (hrtime baseline set)
        nvim_init_start_launch_ms = perf_enabled.launch_ms - perf_enabled.ms_since_start
        nvim_init_start_abs_ns = int(launch_ts_ns + (nvim_init_start_launch_ms * 1e6))

    launcher_exec_tmux_ts_ns = launch_events.get("launcher_exec_tmux_ts_ns")
    tmux_cmd_start_ts_ns = launch_events.get("tmux_cmd_start_ts_ns")
    tmux_client_attached_ts_ns = launch_events.get("tmux_client_attached_ts_ns")

    def delta_ms(a_ns: int | None, b_ns: int | None) -> float | None:
        if a_ns is None or b_ns is None:
            return None
        return (b_ns - a_ns) / 1e6

    open_to_launcher_ms = launch_events.get("open_to_launcher_ms")
    launcher_to_exec_tmux_ms = (launcher_exec_tmux_ts_ns - launch_ts_ns) / 1e6 if isinstance(launcher_exec_tmux_ts_ns, int) else None
    exec_tmux_to_tmux_cmd_ms = (
        delta_ms(launcher_exec_tmux_ts_ns if isinstance(launcher_exec_tmux_ts_ns, int) else None,
                 tmux_cmd_start_ts_ns if isinstance(tmux_cmd_start_ts_ns, int) else None)
    )
    tmux_cmd_to_nvim_init_ms = (
        delta_ms(tmux_cmd_start_ts_ns if isinstance(tmux_cmd_start_ts_ns, int) else None, nvim_init_start_abs_ns)
        if isinstance(nvim_init_start_abs_ns, int)
        else None
    )
    launch_to_nvim_init_ms = nvim_init_start_launch_ms

    nvim_init_to_lazy_done_ms = (
        (lazy_done.launch_ms - nvim_init_start_launch_ms) if lazy_done and isinstance(nvim_init_start_launch_ms, float) else None
    )
    nvim_init_to_prompt_ms = (
        (tt_stdout_first.launch_ms - nvim_init_start_launch_ms)
        if tt_stdout_first and isinstance(nvim_init_start_launch_ms, float)
        else None
    )
    launch_to_prompt_ms = tt_stdout_first.launch_ms if tt_stdout_first else None
    open_to_prompt_ms = (open_to_launcher_ms + launch_to_prompt_ms) if isinstance(open_to_launcher_ms, float) and isinstance(launch_to_prompt_ms, float) else None

    tt_open_ms = (tt_open_done.launch_ms - tt_open_begin.launch_ms) if tt_open_begin and tt_open_done else None
    tt_spawn_ms = (tt_spawn_done.launch_ms - tt_spawn_begin.launch_ms) if tt_spawn_begin and tt_spawn_done else None
    tt_spawn_to_stdout_ms = (tt_stdout_first.launch_ms - tt_spawn_done.launch_ms) if tt_spawn_done and tt_stdout_first else None
    tt_startup_done_to_stdout_ms = (tt_stdout_first.launch_ms - tt_startup_done.launch_ms) if tt_startup_done and tt_stdout_first else None
    nvim_init_to_vim_enter_ms = (
        (vim_enter.launch_ms - nvim_init_start_launch_ms) if vim_enter and isinstance(nvim_init_start_launch_ms, float) else None
    )
    nvim_init_to_ui_enter_ms = (
        (ui_enter.launch_ms - nvim_init_start_launch_ms) if ui_enter and isinstance(nvim_init_start_launch_ms, float) else None
    )
    nvim_init_to_tree_open_ms = (
        (tree_open_done.launch_ms - nvim_init_start_launch_ms)
        if tree_open_done and isinstance(nvim_init_start_launch_ms, float)
        else None
    )

    zshenv_begin_ms = (
        (shell_events.get("toggleterm:zshenv:begin") - launch_ts_ns) / 1e6
        if shell_events.get("toggleterm:zshenv:begin")
        else None
    )
    zshenv_end_ms = (
        (shell_events.get("toggleterm:zshenv:end") - launch_ts_ns) / 1e6
        if shell_events.get("toggleterm:zshenv:end")
        else None
    )
    zshenv_source_begin = shell_events.get("toggleterm:zshenv:source_orig:begin") or shell_events.get("toggleterm:zshenv:source_home:begin")
    zshenv_source_done = shell_events.get("toggleterm:zshenv:source_orig:done") or shell_events.get("toggleterm:zshenv:source_home:done")
    zshenv_source_ms = (zshenv_source_done - zshenv_source_begin) / 1e6 if zshenv_source_begin and zshenv_source_done else None

    zshrc_begin_ms = (
        (shell_events.get("toggleterm:zshrc:begin") - launch_ts_ns) / 1e6
        if shell_events.get("toggleterm:zshrc:begin")
        else None
    )
    zshrc_end_fast_ms = (
        (shell_events.get("toggleterm:zshrc:end_fast_init") - launch_ts_ns) / 1e6
        if shell_events.get("toggleterm:zshrc:end_fast_init")
        else None
    )

    prompt_first_ms = (
        (shell_events.get("toggleterm:prompt:first") - launch_ts_ns) / 1e6
        if shell_events.get("toggleterm:prompt:first")
        else None
    )
    tmux_attach_ms = (
        delta_ms(launch_ts_ns, tmux_client_attached_ts_ns if isinstance(tmux_client_attached_ts_ns, int) else None)
        if isinstance(tmux_client_attached_ts_ns, int)
        else None
    )

    print(f"launch_ts_ns={launch_ts_ns}")
    if isinstance(launch_events.get("tmux_impl"), str):
        print(f"tmux_impl={launch_events['tmux_impl']}")

    print("\n**Ghostty → launcher**")
    print(f"- open→launcher: {fmt_ms(open_to_launcher_ms if isinstance(open_to_launcher_ms, float) else None)}")
    print(f"- open→prompt stdout: {fmt_ms(open_to_prompt_ms)}")
    print(f"- launch→prompt stdout: {fmt_ms(launch_to_prompt_ms)}")
    prompt_ready_ms = prompt_first_ms if isinstance(prompt_first_ms, float) else tmux_attach_ms
    if isinstance(open_to_launcher_ms, float) and isinstance(prompt_ready_ms, float):
        print(f"- open→prompt ready: {fmt_ms(open_to_launcher_ms + prompt_ready_ms)}")
    if isinstance(prompt_first_ms, float):
        print(f"- launch→prompt ready: {fmt_ms(prompt_first_ms)}")
    else:
        print(f"- launch→prompt ready (tmux attach): {fmt_ms(tmux_attach_ms)}")

    print("\n**launcher → tmux**")
    print(f"- launcher→exec tmux: {fmt_ms(launcher_to_exec_tmux_ms)}")
    exec_tmux_to_tmux_attach_ms = (
        delta_ms(
            launcher_exec_tmux_ts_ns if isinstance(launcher_exec_tmux_ts_ns, int) else None,
            tmux_client_attached_ts_ns if isinstance(tmux_client_attached_ts_ns, int) else None,
        )
    )
    launch_to_tmux_attach_ms = (
        delta_ms(launch_ts_ns, tmux_client_attached_ts_ns if isinstance(tmux_client_attached_ts_ns, int) else None)
    )
    attach_to_cmd_start_ms = (
        delta_ms(
            tmux_client_attached_ts_ns if isinstance(tmux_client_attached_ts_ns, int) else None,
            tmux_cmd_start_ts_ns if isinstance(tmux_cmd_start_ts_ns, int) else None,
        )
    )
    print(f"- exec tmux→client attached: {fmt_ms(exec_tmux_to_tmux_attach_ms)}")
    print(f"- launch→client attached: {fmt_ms(launch_to_tmux_attach_ms)}")
    print(f"- exec tmux→tmux cmd start: {fmt_ms(exec_tmux_to_tmux_cmd_ms)}")
    print(f"- client attached→tmux cmd start: {fmt_ms(attach_to_cmd_start_ms)}")
    print(f"- tmux cmd start→nvim init start: {fmt_ms(tmux_cmd_to_nvim_init_ms)}")
    print(f"- launch→nvim init start: {fmt_ms(launch_to_nvim_init_ms)}")

    print("\n**nvim (from init.lua start)**")
    if not perf_enabled or not isinstance(nvim_init_start_launch_ms, float):
        print("- nvim init: n/a (session reused or perf markers missing)")
    else:
        print(f"- init→LazyDone: {fmt_ms(nvim_init_to_lazy_done_ms)}")
        print(f"- init→VimEnter: {fmt_ms(nvim_init_to_vim_enter_ms)}")
        print(f"- init→UIEnter: {fmt_ms(nvim_init_to_ui_enter_ms)}")
        print(f"- init→nvim-tree open done: {fmt_ms(nvim_init_to_tree_open_ms)}")
        print(f"- toggleterm open window: {fmt_ms(tt_open_ms)}")
        print(f"- toggleterm spawn call: {fmt_ms(tt_spawn_ms)}")
        if tt_startup_done:
            print(f"- init→toggleterm startup done: {fmt_ms(tt_startup_done.launch_ms - nvim_init_start_launch_ms)}")
            print(f"- toggleterm startup done→stdout:first: {fmt_ms(tt_startup_done_to_stdout_ms)}")
        print(f"- toggleterm spawn done→stdout:first: {fmt_ms(tt_spawn_to_stdout_ms)}")
        print(f"- init→first toggleterm stdout: {fmt_ms(nvim_init_to_prompt_ms)}")

    print("\n**zsh (toggleterm shell)**")
    print(f"- zshenv begin: {fmt_ms(zshenv_begin_ms)}")
    print(f"- zshenv source (.zshenv): {fmt_ms(zshenv_source_ms)}")
    if zshenv_begin_ms is not None and zshenv_end_ms is not None:
        print(f"- zshenv total: {fmt_ms(zshenv_end_ms - zshenv_begin_ms)}")
    print(f"- zshrc begin: {fmt_ms(zshrc_begin_ms)}")
    print(f"- first prompt (precmd): {fmt_ms(prompt_first_ms)}")
    if zshrc_begin_ms is not None and zshrc_end_fast_ms is not None:
        print(f"- zshrc fast-init body: {fmt_ms(zshrc_end_fast_ms - zshrc_begin_ms)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
