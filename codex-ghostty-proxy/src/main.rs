use anyhow::{Context, Result, anyhow};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, size as terminal_size};
use nix::{
    libc,
    poll::{PollFd, PollFlags, poll},
    unistd,
};
use notify::{RecursiveMode, Watcher};
use portable_pty::{CommandBuilder, PtySize, native_pty_system};
use serde_json::Value;
use signal_hook::{consts::signal::SIGWINCH, iterator::Signals};
use std::{
    env,
    fs::{self, File},
    io::{self, IsTerminal, Read, Seek, SeekFrom, Write},
    os::fd::BorrowedFd,
    path::{Path, PathBuf},
    process::Command,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

const QUERY_TIMEOUT_MS: u16 = 150;
const INPUT_POLL_MS: u16 = 100;
const LOG_POLL_MS: u64 = 250;

const FALLBACK_BASE_BG: Rgb = Rgb {
    r: 0x28,
    g: 0x2c,
    b: 0x34,
};
const THINKING_TARGET: Rgb = Rgb {
    r: 0xff,
    g: 0x68,
    b: 0x72,
};
const DONE_TARGET: Rgb = Rgb {
    r: 0x52,
    g: 0xd1,
    b: 0x8d,
};
const THINKING_ALPHA: f32 = 0.15;
const DONE_ALPHA: f32 = 0.16;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum CodexTurnState {
    Idle,
    Thinking,
    DoneUnread,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum VisualState {
    Normal,
    Thinking,
    DoneUnread,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum CodexEvent {
    TaskStarted,
    TaskComplete,
    TurnAborted,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct Rgb {
    r: u8,
    g: u8,
    b: u8,
}

impl Rgb {
    fn mix(self, target: Self, alpha: f32) -> Self {
        fn blend(base: u8, target: u8, alpha: f32) -> u8 {
            let base = base as f32;
            let target = target as f32;
            ((base * (1.0 - alpha)) + (target * alpha))
                .round()
                .clamp(0.0, 255.0) as u8
        }

        Self {
            r: blend(self.r, target.r, alpha),
            g: blend(self.g, target.g, alpha),
            b: blend(self.b, target.b, alpha),
        }
    }

    fn as_hex(self) -> String {
        format!("{:02x}{:02x}{:02x}", self.r, self.g, self.b)
    }
}

struct RawModeGuard;

impl RawModeGuard {
    fn enable() -> Result<Self> {
        enable_raw_mode().context("failed to enable raw mode")?;
        Ok(Self)
    }
}

impl Drop for RawModeGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
    }
}

#[derive(Clone)]
struct EscapeWriter {
    stdout: Arc<Mutex<io::Stdout>>,
    tmux_passthrough: bool,
}

impl EscapeWriter {
    fn new(tmux_passthrough: bool) -> Self {
        Self {
            stdout: Arc::new(Mutex::new(io::stdout())),
            tmux_passthrough,
        }
    }

    fn stdout_handle(&self) -> Arc<Mutex<io::Stdout>> {
        Arc::clone(&self.stdout)
    }

    fn write_bytes(&self, bytes: &[u8]) -> io::Result<()> {
        let mut stdout = self.stdout.lock().expect("stdout mutex poisoned");
        stdout.write_all(bytes)?;
        stdout.flush()
    }

    fn write_escape(&self, sequence: &str) -> io::Result<()> {
        if self.tmux_passthrough {
            let wrapped = wrap_for_tmux(sequence);
            self.write_bytes(wrapped.as_bytes())
        } else {
            self.write_bytes(sequence.as_bytes())
        }
    }
}

struct Styler {
    writer: EscapeWriter,
    thinking_bg: Rgb,
    done_bg: Rgb,
}

impl Styler {
    fn new(writer: EscapeWriter, base_bg: Rgb) -> Self {
        Self {
            writer,
            thinking_bg: base_bg.mix(THINKING_TARGET, THINKING_ALPHA),
            done_bg: base_bg.mix(DONE_TARGET, DONE_ALPHA),
        }
    }

    fn apply(&self, state: VisualState) -> io::Result<()> {
        match state {
            VisualState::Normal => self.writer.write_escape("\x1b]111\x07"),
            VisualState::Thinking => self
                .writer
                .write_escape(&format!("\x1b]11;#{}\x07", self.thinking_bg.as_hex())),
            VisualState::DoneUnread => self
                .writer
                .write_escape(&format!("\x1b]11;#{}\x07", self.done_bg.as_hex())),
        }
    }
}

struct AppState {
    focused: bool,
    turn: CodexTurnState,
    visual: VisualState,
    styler: Styler,
}

impl AppState {
    fn new(styler: Styler) -> Self {
        Self {
            focused: true,
            turn: CodexTurnState::Idle,
            visual: VisualState::Normal,
            styler,
        }
    }

    fn handle_focus(&mut self, focused: bool) {
        self.focused = focused;
        if focused && self.turn == CodexTurnState::DoneUnread {
            self.turn = CodexTurnState::Idle;
        }
        let _ = self.apply();
    }

    fn handle_codex_event(&mut self, event: CodexEvent) {
        match event {
            CodexEvent::TaskStarted => self.turn = CodexTurnState::Thinking,
            CodexEvent::TaskComplete => {
                self.turn = if self.focused {
                    CodexTurnState::Idle
                } else {
                    CodexTurnState::DoneUnread
                };
            }
            CodexEvent::TurnAborted => self.turn = CodexTurnState::Idle,
        }
        let _ = self.apply();
    }

    fn reset(&mut self) {
        self.turn = CodexTurnState::Idle;
        let _ = self.force(VisualState::Normal);
    }

    fn apply(&mut self) -> io::Result<()> {
        self.force(self.current_visual())
    }

    fn force(&mut self, state: VisualState) -> io::Result<()> {
        if state != self.visual {
            self.styler.apply(state)?;
            self.visual = state;
        } else if state == VisualState::Normal {
            self.styler.apply(state)?;
        }
        Ok(())
    }

    fn current_visual(&self) -> VisualState {
        match self.turn {
            CodexTurnState::Thinking => VisualState::Thinking,
            CodexTurnState::DoneUnread if !self.focused => VisualState::DoneUnread,
            _ => VisualState::Normal,
        }
    }
}

fn main() -> std::process::ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    let real_codex = match resolve_real_codex() {
        Ok(path) => path,
        Err(err) => {
            eprintln!("codex-ghostty-proxy: {err}");
            return std::process::ExitCode::from(1);
        }
    };

    let should_proxy = should_proxy_invocation(&args);
    let result = if should_proxy {
        run_proxy(&real_codex, &args)
    } else {
        run_direct(&real_codex, &args)
    };

    match result {
        Ok(code) => std::process::ExitCode::from(code),
        Err(err) if should_proxy => {
            eprintln!("codex-ghostty-proxy: {err}");
            match run_direct(&real_codex, &args) {
                Ok(code) => std::process::ExitCode::from(code),
                Err(fallback_err) => {
                    eprintln!("codex-ghostty-proxy: fallback failed: {fallback_err}");
                    std::process::ExitCode::from(1)
                }
            }
        }
        Err(err) => {
            eprintln!("codex-ghostty-proxy: {err}");
            std::process::ExitCode::from(1)
        }
    }
}

fn should_proxy_invocation(args: &[String]) -> bool {
    if env::var_os("CODEX_GHOSTTY_PROXY_ACTIVE").is_some() {
        return false;
    }
    if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        return false;
    }
    if !env::var("TERM_PROGRAM")
        .unwrap_or_default()
        .eq_ignore_ascii_case("ghostty")
    {
        return false;
    }
    if let Some(first) = args.first() {
        if matches!(
            first.as_str(),
            "exec"
                | "review"
                | "login"
                | "logout"
                | "mcp"
                | "mcp-server"
                | "app-server"
                | "app"
                | "completion"
                | "sandbox"
                | "debug"
                | "apply"
                | "cloud"
                | "features"
                | "help"
                | "--help"
                | "-h"
                | "--version"
                | "-V"
        ) {
            return false;
        }
    }
    true
}

fn run_direct(real_codex: &Path, args: &[String]) -> Result<u8> {
    let status = Command::new(real_codex)
        .args(args)
        .status()
        .with_context(|| format!("failed to launch {}", real_codex.display()))?;
    Ok(exit_code_from_status(status.code()))
}

fn run_proxy(real_codex: &Path, args: &[String]) -> Result<u8> {
    let _raw_mode = RawModeGuard::enable()?;
    let writer = EscapeWriter::new(env::var_os("TMUX").is_some());
    let base_bg = query_terminal_background(&writer).unwrap_or(FALLBACK_BASE_BG);
    writer.write_escape("\x1b[?1004h")?;

    let mut app_state = AppState::new(Styler::new(writer.clone(), base_bg));
    app_state.reset();
    let shared_state = Arc::new(Mutex::new(app_state));

    let session_log_path = make_session_log_path()?;
    let pty_system = native_pty_system();
    let pty_pair = pty_system
        .openpty(current_pty_size())
        .context("failed to create PTY")?;

    let mut cmd = CommandBuilder::new(real_codex);
    cmd.args(args);
    cmd.cwd(env::current_dir()?);
    cmd.env("CODEX_TUI_RECORD_SESSION", "1");
    cmd.env("CODEX_TUI_SESSION_LOG_PATH", &session_log_path);
    cmd.env("CODEX_GHOSTTY_PROXY_ACTIVE", "1");
    cmd.env_remove("CODEX_GHOSTTY_REAL_CODEX");

    let mut child = pty_pair
        .slave
        .spawn_command(cmd)
        .with_context(|| format!("failed to spawn {}", real_codex.display()))?;
    let mut child_killer = child.clone_killer();

    let mut pty_reader = pty_pair
        .master
        .try_clone_reader()
        .context("failed to clone PTY reader")?;
    let mut pty_writer = pty_pair
        .master
        .take_writer()
        .context("failed to take PTY writer")?;

    let running = Arc::new(AtomicBool::new(true));
    let output_writer = writer.stdout_handle();
    let output_running = Arc::clone(&running);
    let output_thread = thread::spawn(move || -> io::Result<()> {
        let mut buf = [0_u8; 8192];
        loop {
            let read = pty_reader.read(&mut buf)?;
            if read == 0 {
                break;
            }
            let mut stdout = output_writer.lock().expect("stdout mutex poisoned");
            stdout.write_all(&buf[..read])?;
            stdout.flush()?;
        }
        output_running.store(false, Ordering::SeqCst);
        Ok(())
    });

    let resize_running = Arc::clone(&running);
    let resize_master = pty_pair.master;
    let mut signals = Signals::new([SIGWINCH]).context("failed to listen for SIGWINCH")?;
    let resize_handle = signals.handle();
    let resize_thread = thread::spawn(move || -> Result<()> {
        for _ in signals.forever() {
            if !resize_running.load(Ordering::SeqCst) {
                break;
            }
            let _ = resize_master.resize(current_pty_size());
        }
        Ok(())
    });

    let watcher_running = Arc::clone(&running);
    let watcher_state = Arc::clone(&shared_state);
    let watcher_path = session_log_path.clone();
    let log_thread = thread::spawn(move || monitor_session_log(&watcher_path, watcher_state, watcher_running));

    let (exit_tx, exit_rx) = mpsc::channel();
    let wait_thread = thread::spawn(move || {
        let status = child.wait();
        let _ = exit_tx.send(status);
    });

    let stdin_raw_fd = libc::STDIN_FILENO;
    let stdin_fd = unsafe { BorrowedFd::borrow_raw(stdin_raw_fd) };
    let mut pending = Vec::new();

    let status = loop {
        if let Ok(status) = exit_rx.try_recv() {
            break status.context("failed to wait for Codex child")?;
        }

        let mut poll_fds = [PollFd::new(stdin_fd, PollFlags::POLLIN)];
        let ready = poll(&mut poll_fds, INPUT_POLL_MS).context("stdin poll failed")?;
        if ready == 0 {
            continue;
        }

        let mut buf = [0_u8; 1024];
        let read = unistd::read(stdin_raw_fd, &mut buf).context("failed to read stdin")?;
        if read == 0 {
            let _ = child_killer.kill();
            break portable_pty::ExitStatus::with_exit_code(0);
        }

        let forward = strip_focus_sequences(
            &mut pending,
            &buf[..read],
            Arc::clone(&shared_state),
        );
        if !forward.is_empty() {
            pty_writer
                .write_all(&forward)
                .context("failed to forward stdin to PTY")?;
            pty_writer.flush().ok();
        }
    };

    running.store(false, Ordering::SeqCst);
    resize_handle.close();
    drop(pty_writer);

    let _ = wait_thread.join();
    let _ = output_thread.join();
    let _ = resize_thread.join();
    let _ = log_thread.join();

    if let Ok(mut state) = shared_state.lock() {
        state.reset();
    }
    let _ = writer.write_escape("\x1b[?1004l");
    let _ = fs::remove_file(&session_log_path);

    Ok(status.exit_code() as u8)
}

fn resolve_real_codex() -> Result<PathBuf> {
    if let Some(path) = env::var_os("CODEX_GHOSTTY_REAL_CODEX") {
        let path = PathBuf::from(path);
        if path.is_file() {
            return Ok(path);
        }
    }

    let current = env::current_exe().unwrap_or_else(|_| PathBuf::new());
    let path = env::var_os("PATH").ok_or_else(|| anyhow!("PATH is not set"))?;
    for dir in env::split_paths(&path) {
        let candidate = dir.join("codex");
        if candidate.is_file() && candidate != current {
            return Ok(candidate);
        }
    }

    Err(anyhow!("could not locate the real `codex` binary"))
}

fn current_pty_size() -> PtySize {
    let (cols, rows) = terminal_size().unwrap_or((80, 24));
    PtySize {
        rows,
        cols,
        pixel_width: 0,
        pixel_height: 0,
    }
}

fn exit_code_from_status(code: Option<i32>) -> u8 {
    match code {
        Some(code) if (0..=255).contains(&code) => code as u8,
        Some(_) | None => 1,
    }
}

fn make_session_log_path() -> Result<PathBuf> {
    let dir = env::temp_dir().join("codex-ghostty-proxy");
    fs::create_dir_all(&dir).context("failed to create proxy temp directory")?;
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    Ok(dir.join(format!(
        "codex-session-{}-{}.jsonl",
        std::process::id(),
        now
    )))
}

fn query_terminal_background(writer: &EscapeWriter) -> Option<Rgb> {
    writer.write_escape("\x1b]11;?\x07").ok()?;

    let stdin_raw_fd = libc::STDIN_FILENO;
    let stdin_fd = unsafe { BorrowedFd::borrow_raw(stdin_raw_fd) };
    let deadline = Instant::now() + Duration::from_millis(u64::from(QUERY_TIMEOUT_MS));
    let mut bytes = Vec::new();

    while Instant::now() < deadline {
        let remaining = deadline.saturating_duration_since(Instant::now());
        let timeout_ms = remaining.as_millis().min(u128::from(QUERY_TIMEOUT_MS)) as u16;
        let mut poll_fds = [PollFd::new(stdin_fd, PollFlags::POLLIN)];
        let ready = poll(&mut poll_fds, timeout_ms).ok()?;
        if ready == 0 {
            continue;
        }

        let mut buf = [0_u8; 128];
        let read = unistd::read(stdin_raw_fd, &mut buf).ok()?;
        if read == 0 {
            break;
        }
        bytes.extend_from_slice(&buf[..read]);

        if let Some(rgb) = parse_osc11_response(&bytes) {
            return Some(rgb);
        }
    }

    None
}

fn parse_osc11_response(bytes: &[u8]) -> Option<Rgb> {
    let text = String::from_utf8_lossy(bytes);
    let start = text.find("]11;rgb:")?;
    let payload = &text[start + "]11;rgb:".len()..];
    let end = payload.find('\u{7}').or_else(|| payload.find("\x1b\\"))?;
    let colors = &payload[..end];
    let mut parts = colors.split('/');
    let r = parse_hex_component(parts.next()?)?;
    let g = parse_hex_component(parts.next()?)?;
    let b = parse_hex_component(parts.next()?)?;
    Some(Rgb { r, g, b })
}

fn parse_hex_component(component: &str) -> Option<u8> {
    let value = u16::from_str_radix(component, 16).ok()?;
    match component.len() {
        1 => Some((value * 17) as u8),
        2 => Some(value as u8),
        3 => Some(((u32::from(value) * 255) / 0x0fff) as u8),
        4 => Some(((u32::from(value) * 255) / 0xffff) as u8),
        _ => None,
    }
}

fn wrap_for_tmux(sequence: &str) -> String {
    let escaped = sequence.replace('\x1b', "\x1b\x1b");
    format!("\x1bPtmux;{}\x1b\\", escaped)
}

fn monitor_session_log(
    path: &Path,
    state: Arc<Mutex<AppState>>,
    running: Arc<AtomicBool>,
) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| anyhow!("session log path has no parent"))?;
    let (tx, rx) = mpsc::channel();
    let mut watcher = notify::recommended_watcher(move |res| {
        let _ = tx.send(res);
    })
    .context("failed to create file watcher")?;
    watcher
        .watch(parent, RecursiveMode::NonRecursive)
        .context("failed to watch session log directory")?;

    let mut offset = 0_u64;
    let mut partial = String::new();

    while running.load(Ordering::SeqCst) {
        let _ = rx.recv_timeout(Duration::from_millis(LOG_POLL_MS));
        drain_log_file(path, &mut offset, &mut partial, &state)?;
    }

    drain_log_file(path, &mut offset, &mut partial, &state)?;
    Ok(())
}

fn drain_log_file(
    path: &Path,
    offset: &mut u64,
    partial: &mut String,
    state: &Arc<Mutex<AppState>>,
) -> Result<()> {
    let mut file = match File::open(path) {
        Ok(file) => file,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(err) => return Err(err).context("failed to open session log"),
    };

    file.seek(SeekFrom::Start(*offset))
        .context("failed to seek session log")?;
    let mut chunk = String::new();
    file.read_to_string(&mut chunk)
        .context("failed to read session log")?;
    *offset += chunk.len() as u64;

    if chunk.is_empty() {
        return Ok(());
    }

    partial.push_str(&chunk);
    while let Some(idx) = partial.find('\n') {
        let line = partial[..idx].trim_end_matches('\r').to_string();
        partial.drain(..=idx);
        if let Some(event) = parse_codex_event(&line) {
            if let Ok(mut state) = state.lock() {
                state.handle_codex_event(event);
            }
        }
    }

    Ok(())
}

fn parse_codex_event(line: &str) -> Option<CodexEvent> {
    let value: Value = serde_json::from_str(line).ok()?;
    if value.get("type")?.as_str()? != "event_msg" {
        return None;
    }

    match value.get("payload")?.get("type")?.as_str()? {
        "task_started" => Some(CodexEvent::TaskStarted),
        "task_complete" => Some(CodexEvent::TaskComplete),
        "turn_aborted" => Some(CodexEvent::TurnAborted),
        _ => None,
    }
}

fn strip_focus_sequences(
    pending: &mut Vec<u8>,
    incoming: &[u8],
    state: Arc<Mutex<AppState>>,
) -> Vec<u8> {
    let mut combined = Vec::with_capacity(pending.len() + incoming.len());
    combined.extend_from_slice(pending);
    combined.extend_from_slice(incoming);
    pending.clear();

    let mut forwarded = Vec::with_capacity(combined.len());
    let mut idx = 0;
    while idx < combined.len() {
        let remaining = combined.len() - idx;
        if remaining >= 3
            && combined[idx] == 0x1b
            && combined[idx + 1] == b'['
            && matches!(combined[idx + 2], b'I' | b'O')
        {
            let focused = combined[idx + 2] == b'I';
            if let Ok(mut state) = state.lock() {
                state.handle_focus(focused);
            }
            idx += 3;
            continue;
        }

        if remaining < 3 && combined[idx] == 0x1b {
            pending.extend_from_slice(&combined[idx..]);
            break;
        }

        forwarded.push(combined[idx]);
        idx += 1;
    }

    forwarded
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_event_msg_lines() {
        let line = r#"{"type":"event_msg","payload":{"type":"task_complete"}}"#;
        assert_eq!(parse_codex_event(line), Some(CodexEvent::TaskComplete));
    }

    #[test]
    fn parses_osc11_response() {
        let response = b"\x1b]11;rgb:2828/2c2c/3434\x07";
        assert_eq!(parse_osc11_response(response), Some(FALLBACK_BASE_BG));
    }

    #[test]
    fn strips_focus_sequences_without_forwarding_them() {
        let writer = EscapeWriter::new(false);
        let state = Arc::new(Mutex::new(AppState::new(Styler::new(
            writer,
            FALLBACK_BASE_BG,
        ))));
        let mut pending = Vec::new();
        let out = strip_focus_sequences(&mut pending, b"abc\x1b[Odef\x1b[I", Arc::clone(&state));
        assert_eq!(out, b"abcdef");
        assert!(pending.is_empty());
        assert!(state.lock().unwrap().focused);
    }
}
