from pathlib import Path
from typing import Annotated as Ann

from cappa.arg import Arg
from cappa.base import command
from pipeline_helper.models import stage
from pipeline_helper.models.contexts import DirectoryPathSerPosix
from pipeline_helper.models.params import Params
from pipeline_helper.models.path import DataDir
from pydantic import Field

from gjob_pipeline.models.paths import DataFile, paths


class Deps(stage.Deps):
    stage: DirectoryPathSerPosix = Path(__file__).parent
    mboxes: DataDir = paths.mboxes


class Outs(stage.Outs):
    mail: DataFile = paths.mail


@command(default_long=True, invoke="gjob_pipeline.stages.get_mail.__main__.main")
class GetMail(Params[Deps, Outs]):
    """Get mail from mailboxes."""

    deps: Ann[Deps, Arg(hidden=True)] = Field(default_factory=Deps)
    outs: Ann[Outs, Arg(hidden=True)] = Field(default_factory=Outs)
