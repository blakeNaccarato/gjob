from pathlib import Path
from typing import Annotated as Ann

from cappa.arg import Arg
from cappa.base import command
from pipeline_helper.models import stage
from pipeline_helper.models.contexts import DirectoryPathSerPosix
from pipeline_helper.models.params import Params
from pipeline_helper.models.path import DataFile, DocsFile
from pydantic import Field

from gjob_pipeline.models.paths import paths


class Deps(stage.NbDeps):
    stage: DirectoryPathSerPosix = Path(__file__).parent
    nb: DocsFile = paths.notebooks[stage.stem]
    mail: DataFile = paths.mail


class Outs(stage.Outs):
    reqs: DataFile = paths.reqs


@command(default_long=True, invoke="gjob_pipeline.stages.convert.__main__.main")
class Convert(Params[Deps, Outs]):
    """Get job requisitions from mailboxes."""

    deps: Ann[Deps, Arg(hidden=True)] = Field(default_factory=Deps)
    outs: Ann[Outs, Arg(hidden=True)] = Field(default_factory=Outs)
