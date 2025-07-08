"""Contexts."""

from pathlib import Path

from context_models.types import Context
from pydantic import BaseModel, Field

from gjob_pipeline.config import const
from gjob_pipeline.models.contexts.types import Kinds

gjob_pipeline = "gjob_pipeline"
"""Context name for `gjob_pipeline`."""


class Roots(BaseModel):
    """Root directories."""

    data: Path | None = None
    """Data."""
    docs: Path | None = None
    """Docs."""


ROOTED = Roots(data=const.root / const.data, docs=const.root / const.docs)
"""Paths rooted to their directories."""


class GjobPipelineContext(BaseModel):
    """Root directory context."""

    roots: Roots = Field(default_factory=Roots)
    """Root directories for different kinds of paths."""
    kinds: Kinds = Field(default_factory=dict)
    """Kind of each path."""
    track_kinds: bool = False
    """Whether to track kinds."""


class GjobPipelineContexts(Context):
    """AMSL LabJack pipeline context."""

    gjob_pipeline: GjobPipelineContext
