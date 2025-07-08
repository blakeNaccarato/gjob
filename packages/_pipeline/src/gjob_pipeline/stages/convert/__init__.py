from pathlib import Path
from typing import Annotated as Ann

from cappa.arg import Arg
from cappa.base import command
from pydantic import Field

from gjob_pipeline.models import stage
from gjob_pipeline.models.params import Params
from gjob_pipeline.models.path import DataDir, DirectoryPathSerPosix, DocsFile
from gjob_pipeline.models.paths import paths


class Deps(stage.Deps):
    stage: DirectoryPathSerPosix = Path(__file__).parent
    nb: DocsFile = paths.notebooks[stage.stem]
    mboxes: DataDir = paths.mboxes


class Outs(stage.Outs):
    reqs: DataDir = paths.reqs


@command(default_long=True, invoke="gjob_pipeline.stages.convert.__main__.main")
class Convert(Params[Deps, Outs]):
    """Get job requisitions from mailboxes."""

    deps: Ann[Deps, Arg(hidden=True)] = Field(default_factory=Deps)
    outs: Ann[Outs, Arg(hidden=True)] = Field(default_factory=Outs)
