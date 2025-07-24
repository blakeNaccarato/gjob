"""Notebook formatting and display utilities."""

from dataclasses import dataclass
from typing import Any

from devtools import PrettyFormat
from IPython.core.display import Markdown, Pretty
from IPython.display import display
from pydantic import BaseModel
from structlog import get_logger

pretty_format = PrettyFormat(repr_strings=True)

log = get_logger()


@dataclass
class Named:
    name: str
    value: Any


def disp_named(*args: Named | tuple[str, Any]):
    """Display objects with names above them."""
    for arg in args:
        named = arg if isinstance(arg, Named) else Named(*arg)
        display(Markdown(f"##### {named.name}"))
        if isinstance(named.value, str):
            display(Pretty(named.value))
        elif isinstance(named.value, BaseModel):
            display(pretty_format(named.value))
        else:
            display(named.value)
