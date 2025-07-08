"""Types."""

from typing import Annotated as Ann
from typing import Literal, TypeAlias

from cappa.arg import Arg

from gjob_pipeline.models.contexts import GjobPipelineContexts

Key: TypeAlias = Literal["data", "docs"]
"""Data or docs key."""
HiddenContext: TypeAlias = Ann[GjobPipelineContexts, Arg(hidden=True)]
"""Pipeline context as a hidden argument."""
