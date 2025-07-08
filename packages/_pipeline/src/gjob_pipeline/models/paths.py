"""Parameter models for this project."""

from pathlib import Path
from typing import get_args

from gjob_pipeline.models.generated.types.stages import StageName
from gjob_pipeline.models.path import (
    DataDir,
    DocsFile,
    GjobPipelineContextStore,
    get_gjob_pipeline_config,
)


class Paths(GjobPipelineContextStore):
    """Pipeline paths."""

    model_config = get_gjob_pipeline_config(track_kinds=True)
    mboxes: DataDir = Path("mboxes")
    notebooks: dict[str | StageName, DocsFile] = {  # noqa: RUF012
        stage_name: Path("notebooks") / f"{stage_name}.ipynb"
        for stage_name in get_args(StageName)
    }
    reqs: DataDir = Path("reqs")


paths = Paths()
