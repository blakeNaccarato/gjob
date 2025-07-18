from typing import Annotated as Ann

from cappa.arg import Arg
from cappa.base import command
from pipeline_helper.models import stage
from pipeline_helper.models.params import Params
from pipeline_helper.models.path import DataDir
from pydantic import Field

from gjob_pipeline.models.paths import paths


class Outs(stage.Outs):
    mboxes: DataDir = paths.mboxes


@command(default_long=True, invoke="gjob_pipeline.stages.skip_cloud.__main__.main")
class SkipCloud(Params[stage.Deps, Outs]):
    """Keep these outputs local."""

    deps: Ann[stage.Deps, Arg(hidden=True)] = Field(default_factory=stage.Deps)
    outs: Ann[Outs, Arg(hidden=True)] = Field(default_factory=Outs)
