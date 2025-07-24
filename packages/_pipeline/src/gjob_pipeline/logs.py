"""Log configuration."""

from collections.abc import Callable
from pathlib import Path
from sys import stderr
from typing import Any

from devtools import PrettyFormat
from ipykernel.zmqshell import ZMQInteractiveShell
from IPython.core.getipython import get_ipython
from pydantic import BaseModel
from structlog import configure_once, get_config
from structlog.dev import (
    BRIGHT,
    CYAN,
    RESET_ALL,
    Column,
    ConsoleRenderer,
    KeyValueColumnFormatter,
)
from structlog.processors import (
    CallsiteParameter,
    CallsiteParameterAdder,
    JSONRenderer,
    dict_tracebacks,
)
from structlog.typing import EventDict, Processor, ProcessorReturnValue, WrappedLogger

event_key = "event"
injected_nb_key = "_nb"
width = 120
pretty_format = PrettyFormat(
    indent_char=" ", indent_step=2, repr_strings=True, width=width
)


def event_repr(v: dict[str, Any]) -> str:
    return default_repr if len(default_repr := str(v)) < width else pretty_format(v)


def init():
    interactive = stderr.isatty() or isinstance(get_ipython(), ZMQInteractiveShell)
    *preprocessors, renderer = get_config()["processors"]
    configure_once([
        *preprocessors,
        dump_model_events,
        CallsiteParameterAdder([param := CallsiteParameter.MODULE]),
        get_notebook_callsite_param_setter(param),
        *(
            [override_renderer(renderer, param)]
            if interactive
            else [dict_tracebacks, JSONRenderer()]
        ),
    ])


def dump_model_events(
    _logger: WrappedLogger, _method_name: str, event_dict: EventDict
) -> ProcessorReturnValue:
    if (event := event_dict.get(event_key)) and (isinstance(event, BaseModel)):
        event_dict[event_key] = event.model_dump()
    return event_dict


def get_notebook_callsite_param_setter(
    param: CallsiteParameter,
) -> Callable[[WrappedLogger, str, EventDict], ProcessorReturnValue]:
    def set_notebook_callsite_param(
        _logger: WrappedLogger, _method_name: str, event_dict: EventDict
    ) -> ProcessorReturnValue:
        if (event := event_dict.get(event_key)) and (
            (nb := (injected := event.get(injected_nb_key)))
            or ((deps := event.get("deps")) and (nb := deps.get("nb")))
        ):
            event_dict[param.value] = Path(nb).name
            if injected:
                del event[injected_nb_key]
        return event_dict

    return set_notebook_callsite_param


def override_renderer(
    renderer: ConsoleRenderer, callsite_param: CallsiteParameter
) -> Processor:
    cols = {col.key: col for col in renderer._columns}  # noqa: SLF001
    fallback_col = cols.get("") or Column(
        "",
        KeyValueColumnFormatter(
            key_style=RESET_ALL,
            value_style=RESET_ALL,
            reset_style=RESET_ALL,
            value_repr=str,
        ),
    )
    return ConsoleRenderer(
        columns=[
            *([timestamp] if (timestamp := cols.get("timestamp")) else []),
            Column(
                callsite_param.value,
                KeyValueColumnFormatter(
                    key_style=None,
                    value_style=BRIGHT + CYAN,
                    reset_style=RESET_ALL,
                    value_repr=str,
                ),
            ),
            *([level] if (level := cols.get("level")) else []),
            Column(
                event_key,
                KeyValueColumnFormatter(
                    key_style=None,
                    value_style=BRIGHT,
                    reset_style=RESET_ALL,
                    value_repr=event_repr,  # pyright: ignore[reportArgumentType]
                ),
            ),
            fallback_col,
        ]
    )
