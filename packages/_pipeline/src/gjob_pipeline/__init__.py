"""Pipeline."""

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from shlex import join, split
from subprocess import CompletedProcess, run
from tempfile import NamedTemporaryFile

from gjob_pipeline import logs


def init():
    logs.init()


def prettify(string: str) -> str:
    with temporary_path() as path:
        path.write_text(encoding="utf-8", data=string)
        cmd = f"run prettier --no-color --parser 'json' {path.as_posix()}"
        return just(*split(cmd)).stdout.strip()


@contextmanager
def temporary_path() -> Iterator[Path]:
    with NamedTemporaryFile(encoding="utf-8", mode="r", delete=False) as handle:
        path = Path(handle.name)
    try:
        yield path
    finally:
        path.unlink(missing_ok=True)


def just(*args: str) -> CompletedProcess[str]:
    return run(
        args=[
            *split("pwsh -NonInteractive -NoProfile -CommandWithArgs"),
            f"./j.ps1 --color never {join(args)}",
        ],
        check=True,
        capture_output=True,
        encoding="utf-8",
    )


init()
