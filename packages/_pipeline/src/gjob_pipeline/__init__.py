"""Pipeline."""

from __future__ import annotations

from collections.abc import Iterator, Mapping, Sequence
from contextlib import contextmanager
from dataclasses import dataclass, field
from logging import NOTSET, Handler, StreamHandler, _levelToName
from logging.config import dictConfig
from logging.handlers import WatchedFileHandler
from pathlib import Path
from shlex import join, split
from subprocess import CompletedProcess, run
from tempfile import NamedTemporaryFile
from typing import Any, Protocol, runtime_checkable

import structlog
from devtools import PrettyFormat
from structlog import DropEvent, PrintLoggerFactory, configure_once, is_configured
from structlog.contextvars import merge_contextvars
from structlog.dev import (
    BLUE,
    BRIGHT,
    DIM,
    RESET_ALL,
    Column,
    ConsoleRenderer,
    KeyValueColumnFormatter,
    LogLevelColumnFormatter,
    set_exc_info,
)
from structlog.processors import (
    JSONRenderer,
    TimeStamper,
    add_log_level,
    dict_tracebacks,
)
from structlog.stdlib import LoggerFactory, ProcessorFormatter, add_logger_name
from structlog.typing import EventDict, Processor, ProcessorReturnValue, WrappedLogger


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


def get_logger() -> Logger:
    if not is_configured():
        configure(handlers=handlers)
    return structlog.get_logger(__name__)


class Logger(Protocol):
    def msg(self, event: str, **kwds: Any) -> None: ...


def configure(
    processors: Sequence[Processor] | None = None,
    handlers: Mapping[str, HandlerFactory] | None = None,
):
    configure_once(
        cache_logger_on_first_use=True,
        processors=[
            *(processors or []),
            *([ProcessorFormatter.wrap_for_formatter] if handlers else []),
        ],
        logger_factory=LoggerFactory() if handlers else PrintLoggerFactory(),
    )
    if not handlers:
        return
    level = _levelToName[NOTSET]
    dictConfig({
        "version": 1,
        "formatters": {
            k: {
                "()": ProcessorFormatter,
                "processors": [
                    *(handler.processors or []),
                    ProcessorFormatter.remove_processors_meta,
                    *(handler.postprocessors or []),
                    handler.renderer,
                ],
                "foreign_pre_chain": [],
            }
            for k, handler in handlers.items()
        },
        "handlers": {
            k: {
                "level": level,
                "class": f"{handler.factory.__module__}.{handler.factory.__qualname__}",
                "formatter": k,
                **{k: str(v) for k, v in handler.kwds.items()},
            }
            for k, handler in handlers.items()
        },
        "loggers": {"root": {"handlers": list(handlers.keys()), "level": level}},
    })


def drop_ipython_events(
    logger: WrappedLogger,  # noqa: ARG001
    method_name: str,  # noqa: ARG001
    event_dict: EventDict,
) -> ProcessorReturnValue:
    if "ipykernel" in event_dict["_record"].pathname:
        raise DropEvent
    return event_dict


@dataclass
class HandlerFactory:
    factory: type[Handler]
    renderer: Renderer = field(default_factory=JSONRenderer)
    processors: Sequence[Processor] = field(default_factory=list)
    postprocessors: Sequence[Processor] = field(default_factory=list)
    kwds: dict[str, Any] = field(default_factory=dict)


@runtime_checkable
class Renderer(Protocol):
    def __call__(
        self, logger: WrappedLogger, name: str, event_dict: EventDict
    ) -> str | bytes: ...


event_key = "event"
width = 120
pretty_format = PrettyFormat(
    indent_char=" ", indent_step=2, repr_strings=True, width=width
)
common_processors = [
    TimeStamper("iso", utc=False),
    add_log_level,
    add_logger_name,
    merge_contextvars,
    set_exc_info,
]
handlers = {
    "file": HandlerFactory(
        WatchedFileHandler,
        kwds=dict(filename=Path("log.jsonl")),
        renderer=JSONRenderer(),
        processors=[*common_processors, dict_tracebacks],
    ),
    "stream": HandlerFactory(
        StreamHandler,
        processors=[*common_processors, drop_ipython_events],
        renderer=ConsoleRenderer(
            columns=[
                Column(
                    "timestamp",
                    KeyValueColumnFormatter(
                        key_style=None,
                        value_style=DIM,
                        reset_style=RESET_ALL,
                        value_repr=str,
                    ),
                ),
                Column(
                    key="level",
                    formatter=LogLevelColumnFormatter(
                        level_styles=ConsoleRenderer.get_default_level_styles(),
                        reset_style=RESET_ALL,
                    ),
                ),
                Column(
                    "event",
                    KeyValueColumnFormatter(
                        key_style=None,
                        value_style=BRIGHT,
                        reset_style=RESET_ALL,
                        value_repr=lambda v: default_repr
                        if len(default_repr := str(v)) < width
                        else pretty_format(v),
                    ),
                ),
                Column(
                    "logger",
                    logger_formatter := KeyValueColumnFormatter(
                        key_style=None,
                        value_style=BRIGHT + BLUE,
                        reset_style=RESET_ALL,
                        value_repr=str,
                        prefix="[",
                        postfix="]",
                    ),
                ),
                Column(
                    "",
                    KeyValueColumnFormatter(
                        key_style=RESET_ALL,
                        value_style=RESET_ALL,
                        reset_style=RESET_ALL,
                        value_repr=str,
                    ),
                ),
            ]
        ),
    ),
}
