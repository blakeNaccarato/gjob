"""Path models."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from functools import partial
from pathlib import Path
from typing import Annotated as Ann
from typing import ClassVar, Self, TypeAlias

from context_models import ContextStore
from context_models.serializers import ContextWrapSerializer
from context_models.types import Context, ContextPluginSettings, Data, PluginConfigDict
from context_models.validators import ContextAfterValidator
from pydantic import (
    DirectoryPath,
    FilePath,
    SerializerFunctionWrapHandler,
    WrapSerializer,
    model_validator,
)

from gjob_pipeline.models.contexts import (
    GjobPipelineContext,
    GjobPipelineContexts,
    Roots,
    gjob_pipeline,
)
from gjob_pipeline.models.contexts.types import (
    GjobPipelineConfigDict,
    GjobPipelineSerializationInfo,
    GjobPipelineValidationInfo,
    Kind,
)
from gjob_pipeline.models.path.types import HiddenContext, Key
from gjob_pipeline.paths import ISOLIKE, dt_fromisolike


def get_datetime(string: str) -> datetime:
    """Get datetimes."""
    if match := ISOLIKE.search(string):
        return dt_fromisolike(match)
    else:
        raise ValueError("String does not appear to be similar to ISO 8601.")


def get_time(path: Path) -> str:
    """Get timestamp from a path."""
    return match.group() if (match := ISOLIKE.search(path.stem)) else ""


def get_gjob_pipeline_context(
    roots: Roots | None = None,
    kinds_from: GjobPipelineContextStore | None = None,
    track_kinds: bool = False,
) -> GjobPipelineContexts:
    """Context for {mod}`~gjob_pipeline`."""
    ctx_from: GjobPipelineContexts = getattr(
        kinds_from, "context", GjobPipelineContexts(gjob_pipeline=GjobPipelineContext())
    )
    return GjobPipelineContexts(
        gjob_pipeline=GjobPipelineContext(
            roots=roots or Roots(),
            kinds=ctx_from[gjob_pipeline].kinds,
            track_kinds=track_kinds,
        )
    )


def get_gjob_pipeline_config(
    roots: Roots | None = None,
    kinds_from: GjobPipelineContextStore | None = None,
    track_kinds: bool = False,
) -> GjobPipelineConfigDict:
    """Model config for {mod}`~gjob_pipeline`."""
    return PluginConfigDict(
        validate_default=True,
        plugin_settings=ContextPluginSettings(
            context=get_gjob_pipeline_context(
                roots=roots, kinds_from=kinds_from, track_kinds=track_kinds
            )
        ),
    )


class GjobPipelineContextStore(ContextStore):
    """Context model for {mod}`~gjob_pipeline`."""

    model_config: ClassVar[GjobPipelineConfigDict] = (  # pyright: ignore[reportIncompatibleVariableOverride]
        get_gjob_pipeline_config()
    )
    context: HiddenContext = GjobPipelineContexts(  # pyright: ignore[reportIncompatibleVariableOverride]
        gjob_pipeline=GjobPipelineContext()
    )

    @classmethod
    def context_get(
        cls,
        data: Data,
        context: Context | None = None,
        context_base: Context | None = None,
    ) -> Context:
        """Get context from data."""
        return GjobPipelineContexts({  # pyright: ignore[reportArgumentType]
            k: (
                {gjob_pipeline: GjobPipelineContext}[k].model_validate(v)
                if isinstance(v, Mapping)
                else v
            )
            for k, v in super().context_get(data, context, context_base).items()
        })

    @model_validator(mode="after")
    def unset_kinds(self) -> Self:
        """Unset kinds to avoid re-checking them."""
        self.context[gjob_pipeline].kinds = {}
        return self


make_path_args: dict[tuple[Key, bool], Kind] = {
    ("data", False): "DataDir",
    ("data", True): "DataFile",
    ("docs", False): "DocsDir",
    ("docs", True): "DocsFile",
}
"""{func}`~gjob_pipeline.models.path.make_path` args and their kinds."""


def make_path(
    path: Path, info: GjobPipelineValidationInfo, key: Key, file: bool
) -> Path:
    """Check path kind and make a directory and its parents or a file's parents."""
    ctx = info.context[gjob_pipeline]
    root = getattr(ctx.roots, key, None)
    kind = make_path_args[key, file]
    if root:
        path = (root.resolve() / path) if path.is_absolute() else root / path
    if ctx.track_kinds:
        ctx.kinds[path] = kind
    elif ctx.kinds and kind not in ctx.kinds[path.relative_to(root) if root else path]:
        raise ValueError("Path kind not as expected.")
    if root:
        (path.parent if file else path).mkdir(exist_ok=True, parents=True)
    return path


def resolve_path(value: Path | str, nxt: SerializerFunctionWrapHandler) -> str:
    """Resolve paths and serialize POSIX-style."""
    return nxt(Path(value).resolve().as_posix())


def ser_rooted_path(
    value: Path | str,
    nxt: SerializerFunctionWrapHandler,
    info: GjobPipelineSerializationInfo,
    key: Key,
) -> str:
    """Serialize paths POSIX-style, resolving if rooted."""
    ctx = info.context[gjob_pipeline]
    return (
        resolve_path(value, nxt)
        if getattr(ctx.roots, key, None)
        else nxt(Path(value).as_posix())
    )


FilePathSerPosix: TypeAlias = Ann[FilePath, WrapSerializer(resolve_path)]
"""Directory path that serializes as POSIX."""
DirectoryPathSerPosix: TypeAlias = Ann[DirectoryPath, WrapSerializer(resolve_path)]
"""Directory path that serializes as POSIX."""
DataDir: TypeAlias = Ann[
    Path,
    ContextAfterValidator(partial(make_path, key="data", file=False)),
    ContextWrapSerializer(partial(ser_rooted_path, key="data")),
]
"""Data directory path made upon validation."""
DataFile: TypeAlias = Ann[
    Path,
    ContextAfterValidator(partial(make_path, key="data", file=True)),
    ContextWrapSerializer(partial(ser_rooted_path, key="data")),
]
"""Data file path made upon validation."""
DocsDir: TypeAlias = Ann[
    Path,
    ContextAfterValidator(partial(make_path, key="docs", file=False)),
    ContextWrapSerializer(partial(ser_rooted_path, key="docs")),
]
"""Docs directory path made upon validation."""
DocsFile: TypeAlias = Ann[
    Path,
    ContextAfterValidator(partial(make_path, key="docs", file=True)),
    ContextWrapSerializer(partial(ser_rooted_path, key="docs")),
]
"""Docs file path made upon validation."""


def get_path_time(time: str) -> str:
    """Get a path-friendly time string."""
    return time.replace(":", "-")
