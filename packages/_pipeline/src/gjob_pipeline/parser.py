"""Modified Cappa CLI parser that surfaces the first innermost context.

A hacky workaround for now, since Cappa traverses structures differently than vanilla
Pydantic, the uppermost context is not preserved correctly.
"""

from collections.abc import Callable
from typing import Any

from cappa.arg import Arg
from cappa.base import parse_command
from cappa.command import Command
from cappa.help import HelpFormattable
from cappa.invoke import DepTypes, resolve_callable
from cappa.output import Output
from context_models import CONTEXT, ContextStore
from context_models.types import Context
from more_itertools import first
from pipeline_helper.models.contexts import PipelineHelperContexts
from pipeline_helper.models.path import get_pipeline_helper_context
from pydantic import BaseModel


def invoke(
    obj: type | Command[Any],
    *,
    deps: DepTypes = None,
    argv: list[str] | None = None,
    backend: Callable[..., Any] | None = None,
    color: bool = True,
    version: str | Arg[Any] | None = None,
    help: bool | Arg[Any] = True,  # noqa: A002
    completion: bool | Arg[Any] = True,
    theme: Any | None = None,
    output: Output | None = None,
    help_formatter: HelpFormattable | None = None,
):
    """Modified Cappa CLI parser that surfaces the first innermost context."""  # noqa: D401
    command, parsed_command, instance, concrete_output, state = parse_command(
        obj=obj,
        argv=argv,
        backend=backend,
        color=color,
        version=version,
        help=help,
        completion=completion,
        theme=theme,
        output=output,
        help_formatter=help_formatter,
    )
    from gjob_pipeline.cli import Pipeline, Stage  # noqa: PLC0415

    if isinstance(instance, ContextStore):
        instance.context = get_first_innermost_context(instance)
    elif isinstance(instance, Pipeline) and isinstance(instance.commands, Stage):
        instance.commands.commands.context = get_first_innermost_context(
            instance.commands.commands
        )
    resolved, global_deps = resolve_callable(
        command,
        parsed_command,
        instance,
        output=concrete_output,
        state=state,
        deps=deps,
    )
    for dep in global_deps:
        with dep.get(concrete_output):
            pass

    with resolved.get(output=concrete_output) as value:
        return value


def get_first_innermost_context(model: ContextStore) -> PipelineHelperContexts:
    """Get the first innermost context."""
    context = model.context
    m = model
    while isinstance(
        (m := first((v for k, v in dict(m).items() if k != "context"), default=None)),
        BaseModel,
    ):
        context: Context = dict(m).get(CONTEXT, get_pipeline_helper_context())
    return context  # pyright: ignore[reportReturnType]


def PairedArg(name: str) -> Arg[Any]:  # noqa: N802
    """Create a paired argument, enabling the `--no-` prefix."""
    name = name.replace("_", "-")
    return Arg(long=[f"--{name}", f"--no-{name}"])
