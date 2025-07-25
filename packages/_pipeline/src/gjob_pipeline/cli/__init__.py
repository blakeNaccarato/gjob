"""Command-line interface."""

from __future__ import annotations

from dataclasses import dataclass

from cappa.base import command
from cappa.subcommand import Subcommands
from pipeline_helper.sync_dvc import SyncDvc

from gjob_pipeline.stages.convert import Convert
from gjob_pipeline.stages.example import Example
from gjob_pipeline.stages.get_mail import GetMail


@dataclass
class Stage:
    """Run a pipeline stage."""

    commands: Subcommands[Example | Convert | GetMail]


@command(name="gjob-pipeline")
class Pipeline:
    """Run the research data pipeline."""

    commands: Subcommands[SyncDvc | Stage]
